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
        
        // Load identifiers from each collection
        for collection in collections {
            let collectionIdentifiers = try dbService.loadIdentifiersForCollection(collection.name)
            identifiers.append(contentsOf: collectionIdentifiers)
        }
        
        if identifiers.isEmpty {
            Logger.metadata.error("No identifiers found in the database")
            throw NSError(domain: "ArchiveService", code: 5, userInfo: [NSLocalizedDescriptionKey: "No identifiers found in the database"])
        }
        
        Logger.metadata.info("Loaded \(identifiers.count) identifiers from \(self.collections.count) collections")
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
            // When using custom collections, just select randomly from all available identifiers
            Logger.metadata.info("Using random selection from user-selected collections")
            return identifiers.randomElement()
        }
        
        // Continue with default preferred/not-preferred behavior
        guard !collections.isEmpty else {
            Logger.metadata.error("No collections available for random selection")
            return identifiers.randomElement()
        }
        
        // Separate collections into preferred and non-preferred
        let preferredCollections = collections.filter { $0.preferred }
        let nonPreferredCollections = collections.filter { !$0.preferred }
        
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
        let mp4Files = metadata.files.filter { $0.format == "MPEG4" || ($0.name.hasSuffix(".mp4")) }
        return mp4Files
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