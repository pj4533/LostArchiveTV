//
//  ArchiveService.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import Foundation
import OSLog

// MARK: - ArchiveError
enum ArchiveError: Error, LocalizedError {
    case contentDeleted
    case contentRestricted
    case invalidFormat
    case noIdentifiersFound
    case metadataDecodingFailed(identifier: String)
    
    var errorDescription: String? {
        switch self {
        case .contentDeleted:
            return "The requested content has been deleted from the archive"
        case .contentRestricted:
            return "The requested content is restricted and cannot be accessed"
        case .invalidFormat:
            return "The content format is invalid or unsupported"
        case .noIdentifiersFound:
            return "No identifiers found in the database"
        case .metadataDecodingFailed(let identifier):
            return "Failed to decode metadata for identifier: \(identifier)"
        }
    }
}

actor ArchiveService {
    private let dbService: DatabaseService
    private var collections: [ArchiveCollection] = []

    // Cache for all loaded identifiers
    private var cachedIdentifiers: [ArchiveIdentifier]?
    // Cache for collection-specific identifiers
    private var collectionIdentifiersCache: [String: [ArchiveIdentifier]] = [:]

    init() {
        self.dbService = DatabaseService.shared

        // Try to initialize database and collections
        do {
            try dbService.openDatabase()
            // Load collections once during initialization - they'll be cached in DatabaseService
            collections = try dbService.loadCollections()
        } catch {
            Logger.metadata.error("Failed to initialize SQLite database: \(error.localizedDescription)")
        }
    }

    deinit {
        // We no longer close the database here since it's a shared instance
    }

    // Method to clear all caches when preferences change
    func clearIdentifierCaches() {
        Logger.metadata.debug("Clearing all identifier caches")
        cachedIdentifiers = nil
        collectionIdentifiersCache.removeAll()
    }

    // MARK: - Metadata Loading
    func loadArchiveIdentifiers() async throws -> [ArchiveIdentifier] {
        // Return cached identifiers if available
        if let cachedIdentifiers = cachedIdentifiers {
            Logger.metadata.debug("Using cached identifiers (\(cachedIdentifiers.count) identifiers)")
            return cachedIdentifiers
        }

        Logger.metadata.debug("Loading archive identifiers from SQLite database")

        // Ensure collections are loaded
        if collections.isEmpty {
            collections = try dbService.loadCollections()
        }

        var identifiers: [ArchiveIdentifier] = []

        // Load identifiers from each collection (excluding those marked as excluded)
        for collection in collections where !collection.excluded {
            let collectionIdentifiers = try dbService.loadIdentifiersForCollection(collection.name)
            identifiers.append(contentsOf: collectionIdentifiers)

            // Cache the collection identifiers
            collectionIdentifiersCache[collection.name] = collectionIdentifiers
        }

        if identifiers.isEmpty {
            Logger.metadata.error("No identifiers found in the database")
            throw ArchiveError.noIdentifiersFound
        }

        let nonExcludedCollectionsCount = collections.filter { !$0.excluded }.count
        Logger.metadata.info("Loaded \(identifiers.count) identifiers from \(nonExcludedCollectionsCount) non-excluded collections")

        // Cache the full identifier list
        cachedIdentifiers = identifiers

        return identifiers
    }
    
    func loadIdentifiersForCollection(_ collectionName: String) async throws -> [ArchiveIdentifier] {
        // Check if we have these identifiers cached
        if let cachedCollectionIdentifiers = collectionIdentifiersCache[collectionName] {
            Logger.metadata.debug("Using cached identifiers for collection: \(collectionName) (\(cachedCollectionIdentifiers.count) identifiers)")
            return cachedCollectionIdentifiers
        }

        Logger.metadata.debug("Loading archive identifiers for collection: \(collectionName)")

        let identifiers = try dbService.loadIdentifiersForCollection(collectionName)

        if identifiers.isEmpty {
            Logger.metadata.warning("No identifiers found for collection: \(collectionName)")
        } else {
            Logger.metadata.info("Loaded \(identifiers.count) identifiers from collection \(collectionName)")
        }

        // Cache the identifiers for this collection
        collectionIdentifiersCache[collectionName] = identifiers

        return identifiers
    }
    
    func fetchMetadata(for identifier: String) async throws -> ArchiveMetadata {
        let metadataURL = URL(string: "https://archive.org/metadata/\(identifier)")!
        Logger.network.debug("Fetching metadata from: \(metadataURL)")
        
        // Create URLSession configuration with cache
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        let session = URLSession(configuration: config)
        
        let requestStartTime = CFAbsoluteTimeGetCurrent()
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: metadataURL)
        } catch let urlError as URLError {
            // Map URLError cases to appropriate NetworkError types
            Logger.network.error("URL error occurred: \(urlError.localizedDescription)")
            switch urlError.code {
            case .notConnectedToInternet:
                throw NetworkError.noInternetConnection
            case .timedOut:
                throw NetworkError.timeout
            case .cannotFindHost, .cannotConnectToHost, .networkConnectionLost:
                throw NetworkError.connectionError(message: urlError.localizedDescription)
            default:
                // For other URLError cases, wrap in a generic connection error
                throw NetworkError.connectionError(message: "Network request failed: \(urlError.localizedDescription)")
            }
        }
        let requestTime = CFAbsoluteTimeGetCurrent() - requestStartTime
        
        if let httpResponse = response as? HTTPURLResponse {
            Logger.network.debug("Metadata response: HTTP \(httpResponse.statusCode), size: \(data.count) bytes, time: \(requestTime.formatted(.number.precision(.fractionLength(4)))) seconds")
            
            // Handle specific HTTP status codes for permanent content failures
            switch httpResponse.statusCode {
            case 404:
                Logger.network.error("Content not found (404) for identifier: \(identifier)")
                throw ArchiveError.contentDeleted
            case 403:
                Logger.network.error("Access forbidden (403) for identifier: \(identifier)")
                throw ArchiveError.contentRestricted
            case 451:
                Logger.network.error("Content unavailable for legal reasons (451) for identifier: \(identifier)")
                throw ArchiveError.contentRestricted
            case 200..<300:
                // Success, continue processing
                break
            default:
                // For other non-success status codes, throw a network error
                Logger.network.error("Unexpected HTTP status \(httpResponse.statusCode) for identifier: \(identifier)")
                throw NetworkError.serverError(statusCode: httpResponse.statusCode, message: "Failed to fetch metadata")
            }
        }
        
        let decodingStartTime = CFAbsoluteTimeGetCurrent()
        let metadata: ArchiveMetadata
        do {
            metadata = try JSONDecoder().decode(ArchiveMetadata.self, from: data)
        } catch {
            Logger.network.error("Failed to decode metadata for identifier \(identifier): \(error)")
            throw ArchiveError.metadataDecodingFailed(identifier: identifier)
        }
        let decodingTime = CFAbsoluteTimeGetCurrent() - decodingStartTime
        
        Logger.metadata.debug("Decoded metadata with \(metadata.files.count) files in \(decodingTime.formatted(.number.precision(.fractionLength(4)))) seconds")
        return metadata
    }
    
    func getRandomIdentifier(from identifiers: [ArchiveIdentifier]) -> ArchiveIdentifier? {
        // Delegate the selection logic to the dedicated IdentifierSelectionService
        // This provides a clear centralized place for all identifier selection logic
        return IdentifierSelectionService.shared.selectRandomIdentifier(
            from: identifiers,
            collections: collections
        )
    }
    
    func findPlayableFiles(in metadata: ArchiveMetadata) throws -> [ArchiveFile] {
        let identifier = metadata.metadata?.identifier ?? "unknown"
        
        // Log the total number of files available in metadata
        Logger.files.info("🔍 [\(identifier)] TOTAL FILES: \(metadata.files.count) files found in metadata")
        
        // Count all video files before grouping
        let allVideoFiles = metadata.files.filter { 
            $0.name.hasSuffix(".mp4") || 
            $0.format == "h.264 IA" || 
            $0.format == "h.264" || 
            $0.format == "MPEG4" 
        }
        Logger.files.info("🔍 [\(identifier)] VIDEO FILES: \(allVideoFiles.count) video files found before grouping")
        
        // Create file groups by name (without extension)
        var fileGroups: [String: [ArchiveFile]] = [:]
        
        // Group files that represent the same content but in different formats
        for file in metadata.files {
            // Skip non-video files or files without names
            guard file.name.hasSuffix(".mp4") || 
                  file.format == "h.264 IA" || 
                  file.format == "h.264" || 
                  file.format == "MPEG4" else {
                continue
            }
            
            // Extract base name without extension to group files
            let baseName = file.name.replacingOccurrences(of: "\\.mp4$", with: "", options: .regularExpression)
            
            if fileGroups[baseName] == nil {
                fileGroups[baseName] = []
            }
            fileGroups[baseName]?.append(file)
        }
        
        // Log the number of unique base names (groups)
        Logger.files.info("🔢 [\(identifier)] UNIQUE VIDEOS: \(fileGroups.count) unique videos found after grouping")
        
        // Process each group to select format priority
        var selectedFiles: [ArchiveFile] = []
        var formatCounts: [String: Int] = [:]
        
        for (_, files) in fileGroups {
            // Check for each format in priority order
            let h264IAFile = files.first { $0.format == "h.264 IA" }
            let h264File = files.first { $0.format == "h.264" }
            let mp4File = files.first { $0.format == "MPEG4" || $0.name.hasSuffix(".mp4") }
            
            // Add the highest priority format available for this file
            if let file = h264IAFile {
                selectedFiles.append(file)
                formatCounts["h.264 IA"] = (formatCounts["h.264 IA"] ?? 0) + 1
            } else if let file = h264File {
                selectedFiles.append(file)
                formatCounts["h.264"] = (formatCounts["h.264"] ?? 0) + 1
            } else if let file = mp4File {
                selectedFiles.append(file)
                formatCounts["MPEG4"] = (formatCounts["MPEG4"] ?? 0) + 1
            }
        }
        
        // Log format distribution
        let formatSummary = formatCounts.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        Logger.files.info("📊 [\(identifier)] FORMAT DISTRIBUTION: \(formatSummary)")
        
        // If we don't have any files after grouping (which could happen if the grouping logic has issues),
        // fall back to the old method
        if selectedFiles.isEmpty {
            Logger.files.warning("⚠️ [\(identifier)] No files selected using per-file priority, falling back to legacy method")
            
            // First look for h.264 IA format files (highest priority)
            let h264IAFiles = metadata.files.filter { $0.format == "h.264 IA" }
            
            // If h.264 IA files exist, return those
            if !h264IAFiles.isEmpty {
                Logger.files.info("📊 [\(identifier)] LEGACY: Found \(h264IAFiles.count) h.264 IA format files")
                return h264IAFiles
            }
            
            // Second, look for h.264 format files
            let h264Files = metadata.files.filter { $0.format == "h.264" }
            
            // If h.264 files exist, return those
            if !h264Files.isEmpty {
                Logger.files.info("📊 [\(identifier)] LEGACY: No h.264 IA files found. Found \(h264Files.count) h.264 format files")
                return h264Files
            }
            
            // Finally fall back to MPEG4 files
            let mp4Files = metadata.files.filter { $0.format == "MPEG4" || ($0.name.hasSuffix(".mp4")) }
            Logger.files.info("📊 [\(identifier)] LEGACY: No h.264 IA or h.264 files found, falling back to \(mp4Files.count) MPEG4 files")
            return mp4Files
        }
        
        Logger.files.info("📊 [\(identifier)] FINAL SELECTION: \(selectedFiles.count) playable files selected from \(fileGroups.count) unique videos")
        
        // If no playable files found, check if there were any files at all
        if selectedFiles.isEmpty && !metadata.files.isEmpty {
            Logger.files.error("[\(identifier)] No playable video files found despite having \(metadata.files.count) total files")
            throw ArchiveError.invalidFormat
        }
        
        return selectedFiles
    }
    
    /// Selects a file from an array of playable files, deprioritizing very short clips
    /// - Parameter files: Array of playable files (already filtered by format priority)
    /// - Returns: A selected file, with reduced likelihood of selecting clips under 1 minute
    func selectFilePreferringLongerDurations(from files: [ArchiveFile]) -> ArchiveFile? {
        guard !files.isEmpty else {
            Logger.metadata.error("Cannot select file from empty array")
            return nil
        }
        
        // If only one file, return it
        if files.count == 1 {
            return files.first
        }
        
        // Extract durations for files that have them
        var filesWithDuration: [(file: ArchiveFile, duration: Double)] = []
        
        for file in files {
            if let lengthStr = file.length {
                var estimatedDuration: Double = 0
                
                // Parse as direct seconds
                if let directSeconds = Double(lengthStr) {
                    estimatedDuration = directSeconds
                }
                // Parse as HH:MM:SS format
                else if lengthStr.contains(":") {
                    let components = lengthStr.components(separatedBy: ":")
                    if components.count == 3, 
                       let hours = Double(components[0]),
                       let minutes = Double(components[1]),
                       let seconds = Double(components[2]) {
                        estimatedDuration = hours * 3600 + minutes * 60 + seconds
                    }
                }
                
                if estimatedDuration > 0 {
                    filesWithDuration.append((file: file, duration: estimatedDuration))
                }
            }
        }
        
        // If no files have duration info, fall back to random selection
        if filesWithDuration.isEmpty {
            Logger.metadata.info("No duration information available, using random selection")
            return files.randomElement()
        }
        
        // Define threshold for "very short" clips (600 seconds = 10 minutes)
        let shortClipThreshold: Double = 600.0
        
        // Separate files into "normal" and "very short" categories
        let normalDurationFiles = filesWithDuration.filter { $0.duration >= shortClipThreshold }
        let shortClipFiles = filesWithDuration.filter { $0.duration < shortClipThreshold }
        
        // If we have normal-length files, almost always pick from those (99% chance)
        // but very occasionally allow short clips (1% chance)
        if !normalDurationFiles.isEmpty {
            // Determine if we should select from normal-length files or short clips
            let allowShortClip = Double.random(in: 0..<1.0) < 0.01 // 1% chance to allow short clips
            
            if allowShortClip && !shortClipFiles.isEmpty {
                // Select a random short clip
                let selectedShortClip = shortClipFiles.randomElement()!
                Logger.metadata.info("Selected short clip with duration \(selectedShortClip.duration)s (randomly allowed)")
                return selectedShortClip.file
            } else {
                // Select a random normal-length file (all treated with equal weight)
                let selectedNormalFile = normalDurationFiles.randomElement()!
                Logger.metadata.info("Selected normal-length file with duration \(selectedNormalFile.duration)s")
                return selectedNormalFile.file
            }
        } else {
            // All files are short clips, just pick randomly from what we have
            let selectedFile = filesWithDuration.randomElement()!
            Logger.metadata.info("All files are short clips, selected file with duration \(selectedFile.duration)s")
            return selectedFile.file
        }
    }
    
    func getFileDownloadURL(for file: ArchiveFile, identifier: String) -> URL? {
        return URL(string: "https://archive.org/download/\(identifier)/\(file.name)")
    }
    
    func estimateDuration(fromFile file: ArchiveFile) -> Double {
        var estimatedDuration: Double = 0
        
        if let lengthStr = file.length {
            Logger.metadata.debug("Found duration string in metadata: \(lengthStr)")
            
            // First, try to parse as a direct number of seconds (e.g., "1724.14")
            if let directSeconds = Double(lengthStr) {
                estimatedDuration = directSeconds
                Logger.metadata.debug("Parsed direct seconds value: \(estimatedDuration) seconds")
            }
            // If that fails, try to parse as HH:MM:SS format
            else if lengthStr.contains(":") {
                let components = lengthStr.components(separatedBy: ":")
                if components.count == 3, 
                   let hours = Double(components[0]),
                   let minutes = Double(components[1]),
                   let seconds = Double(components[2]) {
                    estimatedDuration = hours * 3600 + minutes * 60 + seconds
                    Logger.metadata.debug("Parsed HH:MM:SS format: \(estimatedDuration) seconds")
                }
            }
        }
        
        // Set a default approximate duration if we couldn't get one (30 minutes)
        if estimatedDuration <= 0 {
            estimatedDuration = 1800
            Logger.metadata.debug("Using default duration: \(estimatedDuration) seconds")
        } else {
            Logger.metadata.debug("Using extracted duration: \(estimatedDuration) seconds")
        }
        
        return estimatedDuration
    }
}