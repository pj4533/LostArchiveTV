//
//  ArchiveService.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import Foundation
import OSLog
import SQLite3

actor ArchiveService {
    private var db: OpaquePointer?
    private var collections: [ArchiveCollection] = []
    
    init() {
        // Try to open the database at app startup
        do {
            try openDatabase()
            try loadCollections()
        } catch {
            Logger.metadata.error("Failed to initialize SQLite database: \(error.localizedDescription)")
        }
    }
    
    deinit {
        closeDatabase()
    }
    
    private func openDatabase() throws {
        // Get the path to the SQLite database file
        guard let dbPath = Bundle.main.path(forResource: "identifiers", ofType: "sqlite") else {
            Logger.metadata.error("Failed to find SQLite database file")
            throw NSError(domain: "ArchiveService", code: 1, userInfo: [NSLocalizedDescriptionKey: "SQLite database file not found"])
        }
        
        // Open the database
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            closeDatabase()
            Logger.metadata.error("Failed to open SQLite database: \(errorMessage)")
            throw NSError(domain: "ArchiveService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to open SQLite database: \(errorMessage)"])
        }
        
        Logger.metadata.debug("Successfully opened SQLite database at \(dbPath)")
    }
    
    private func closeDatabase() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }
    
    private func loadCollections() throws {
        // Ensure database is open
        guard db != nil else {
            try openDatabase()
            return
        }
        
        collections = []
        
        // Query for collections with preferred status
        let queryString = "SELECT name, preferred FROM collections"
        var queryStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, queryString, -1, &queryStatement, nil) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            Logger.metadata.error("Failed to prepare collections query: \(errorMessage)")
            throw NSError(domain: "ArchiveService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare query: \(errorMessage)"])
        }
        
        // Execute the query and process results
        while sqlite3_step(queryStatement) == SQLITE_ROW {
            if let collectionCString = sqlite3_column_text(queryStatement, 0) {
                let collectionName = String(cString: collectionCString)
                let preferred = sqlite3_column_int(queryStatement, 1) == 1
                collections.append(ArchiveCollection(name: collectionName, preferred: preferred))
            }
        }
        
        // Finalize the statement
        sqlite3_finalize(queryStatement)
        
        if collections.isEmpty {
            Logger.metadata.error("No collections found in the database")
            throw NSError(domain: "ArchiveService", code: 4, userInfo: [NSLocalizedDescriptionKey: "No collections found in the database"])
        }
        
        Logger.metadata.info("Loaded \(self.collections.count) collections from the database, including \(self.collections.filter { $0.preferred }.count) preferred collections")
    }
    
    // MARK: - Metadata Loading
    func loadArchiveIdentifiers() async throws -> [ArchiveIdentifier] {
        Logger.metadata.debug("Loading archive identifiers from SQLite database")
        
        // Ensure database is open and collections are loaded
        if db == nil {
            try openDatabase()
        }
        
        if collections.isEmpty {
            try loadCollections()
        }
        
        var identifiers: [ArchiveIdentifier] = []
        
        // Load identifiers from each collection
        for collection in collections {
            let collectionIdentifiers = try loadIdentifiersForCollection(collection.name)
            identifiers.append(contentsOf: collectionIdentifiers)
        }
        
        if identifiers.isEmpty {
            Logger.metadata.error("No identifiers found in the database")
            throw NSError(domain: "ArchiveService", code: 5, userInfo: [NSLocalizedDescriptionKey: "No identifiers found in the database"])
        }
        
        Logger.metadata.info("Loaded \(identifiers.count) identifiers from \(self.collections.count) collections")
        return identifiers
    }
    
    private func loadIdentifiersForCollection(_ collection: String) throws -> [ArchiveIdentifier] {
        var identifiers: [ArchiveIdentifier] = []
        
        // Create a query to get all identifiers from the collection table
        let queryString = "SELECT identifier FROM \"\(collection)\""
        var queryStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, queryString, -1, &queryStatement, nil) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            Logger.metadata.error("Failed to prepare identifiers query for \(collection): \(errorMessage)")
            throw NSError(domain: "ArchiveService", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare query: \(errorMessage)"])
        }
        
        // Execute the query and process results
        while sqlite3_step(queryStatement) == SQLITE_ROW {
            if let identifierCString = sqlite3_column_text(queryStatement, 0) {
                let identifier = String(cString: identifierCString)
                identifiers.append(ArchiveIdentifier(identifier: identifier, collection: collection))
            }
        }
        
        // Finalize the statement
        sqlite3_finalize(queryStatement)
        
        Logger.metadata.debug("Loaded \(identifiers.count) identifiers from collection '\(collection)'")
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
        
        Logger.metadata.info("Collection pool: \(selectionPool)")
        
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
