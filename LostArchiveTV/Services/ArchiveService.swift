//
//  ArchiveService.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import Foundation
import OSLog

actor ArchiveService {
    private let dbService: DatabaseService
    private var collections: [ArchiveCollection] = []
    
    init() {
        self.dbService = DatabaseService()
        
        // Try to initialize database and collections
        do {
            try dbService.openDatabase()
            try loadCollections()
        } catch {
            Logger.metadata.error("Failed to initialize SQLite database: \(error.localizedDescription)")
        }
    }
    
    deinit {
        dbService.closeDatabase()
    }
    
    private func loadCollections() throws {
        collections = try dbService.loadCollections()
        Logger.metadata.info("Loaded \(self.collections.count) collections from the database, including \(self.collections.filter { $0.preferred }.count) preferred collections")
    }
    
    // MARK: - Metadata Loading
    func loadArchiveIdentifiers() async throws -> [ArchiveIdentifier] {
        Logger.metadata.debug("Loading archive identifiers from SQLite database")
        
        // Ensure collections are loaded
        if collections.isEmpty {
            try loadCollections()
        }
        
        var identifiers: [ArchiveIdentifier] = []
        
        // Load identifiers from each collection (excluding those marked as excluded)
        for collection in collections where !collection.excluded {
            let collectionIdentifiers = try dbService.loadIdentifiersForCollection(collection.name)
            identifiers.append(contentsOf: collectionIdentifiers)
        }
        
        if identifiers.isEmpty {
            Logger.metadata.error("No identifiers found in the database")
            throw NSError(domain: "ArchiveService", code: 5, userInfo: [NSLocalizedDescriptionKey: "No identifiers found in the database"])
        }
        
        let nonExcludedCollectionsCount = collections.filter { !$0.excluded }.count
        Logger.metadata.info("Loaded \(identifiers.count) identifiers from \(nonExcludedCollectionsCount) non-excluded collections")
        return identifiers
    }
    
    func loadIdentifiersForCollection(_ collectionName: String) async throws -> [ArchiveIdentifier] {
        Logger.metadata.debug("Loading archive identifiers for collection: \(collectionName)")
        
        let identifiers = try dbService.loadIdentifiersForCollection(collectionName)
        
        if identifiers.isEmpty {
            Logger.metadata.warning("No identifiers found for collection: \(collectionName)")
        } else {
            Logger.metadata.info("Loaded \(identifiers.count) identifiers from collection \(collectionName)")
        }
        
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
        let (data, response) = try await session.data(from: metadataURL)
        let requestTime = CFAbsoluteTimeGetCurrent() - requestStartTime
        
        if let httpResponse = response as? HTTPURLResponse {
            Logger.network.debug("Metadata response: HTTP \(httpResponse.statusCode), size: \(data.count) bytes, time: \(requestTime.formatted(.number.precision(.fractionLength(4)))) seconds")
        }
        
        let decodingStartTime = CFAbsoluteTimeGetCurrent()
        let metadata = try JSONDecoder().decode(ArchiveMetadata.self, from: data)
        let decodingTime = CFAbsoluteTimeGetCurrent() - decodingStartTime
        
        Logger.metadata.debug("Decoded metadata with \(metadata.files.count) files in \(decodingTime.formatted(.number.precision(.fractionLength(4)))) seconds")
        return metadata
    }
    
    func getRandomIdentifier(from identifiers: [ArchiveIdentifier]) -> ArchiveIdentifier? {
        // First check if user has disabled default collection behavior
        if !CollectionPreferences.shouldUseDefaultCollections() {
            // When using custom collections, use the dedicated method to select from enabled collections
            Logger.metadata.info("Using random selection from user-selected collections")
            let enabledCollections = CollectionPreferences.getEnabledCollections() ?? []
            
            if !enabledCollections.isEmpty {
                do {
                    return try dbService.getRandomIdentifierFromEnabledCollections(enabledCollections)
                } catch {
                    Logger.metadata.error("Failed to get random identifier from enabled collections: \(error.localizedDescription), falling back to random selection")
                }
            } else {
                Logger.metadata.warning("No enabled collections found, falling back to random selection")
            }
            return identifiers.randomElement()
        }
        
        // Continue with default preferred/not-preferred behavior
        guard !collections.isEmpty else {
            Logger.metadata.error("No collections available for random selection")
            return identifiers.randomElement()
        }
        
        // Filter out excluded collections first
        let allowedCollections = collections.filter { !$0.excluded }
        
        // If all collections are excluded, fall back to random selection
        guard !allowedCollections.isEmpty else {
            Logger.metadata.warning("All collections are excluded, falling back to random selection")
            return identifiers.randomElement()
        }
        
        // Separate collections into preferred and non-preferred (from non-excluded collections)
        let preferredCollections = allowedCollections.filter { $0.preferred }
        let nonPreferredCollections = allowedCollections.filter { !$0.preferred }
        
        // Create a selection pool where:
        // - Each preferred collection gets one entry
        // - All non-preferred collections together get one entry
        var selectionPool: [String] = preferredCollections.map { $0.name }
        if !nonPreferredCollections.isEmpty {
            selectionPool.append("non-preferred")
        }
        
        Logger.metadata.info("Collection pool (default behavior): \(selectionPool)")
        
        // Randomly select from the pool
        guard let selection = selectionPool.randomElement() else {
            Logger.metadata.error("Failed to select from collection pool")
            return identifiers.randomElement()
        }
        
        if selection == "non-preferred" {
            // Randomly select one of the non-preferred collections
            guard let randomNonPreferredCollection = nonPreferredCollections.randomElement() else {
                Logger.metadata.error("Failed to select a non-preferred collection")
                return identifiers.randomElement()
            }
            
            // Filter identifiers for the selected non-preferred collection
            let collectionIdentifiers = identifiers.filter { $0.collection == randomNonPreferredCollection.name }
            
            if collectionIdentifiers.isEmpty {
                Logger.metadata.warning("No identifiers found for non-preferred collection '\(randomNonPreferredCollection.name)', selecting from all identifiers")
                return identifiers.randomElement()
            }
            
            Logger.metadata.debug("Selected non-preferred collection: \(randomNonPreferredCollection.name)")
            return collectionIdentifiers.randomElement()
        } else {
            // We selected a specific preferred collection
            // Filter identifiers for the selected preferred collection
            let collectionIdentifiers = identifiers.filter { $0.collection == selection }
            
            if collectionIdentifiers.isEmpty {
                Logger.metadata.warning("No identifiers found for preferred collection '\(selection)', selecting from all identifiers")
                return identifiers.randomElement()
            }
            
            Logger.metadata.debug("Selected preferred collection: \(selection)")
            return collectionIdentifiers.randomElement()
        }
    }
    
    func findPlayableFiles(in metadata: ArchiveMetadata) -> [ArchiveFile] {
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
        
        // Define threshold for "very short" clips (60 seconds = 1 minute)
        let shortClipThreshold: Double = 60.0
        
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