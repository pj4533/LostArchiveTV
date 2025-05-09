//
//  DatabaseService.swift
//  LostArchiveTV
//
//  Created by Claude on 4/21/25.
//

import Foundation
import OSLog
import SQLite3

class DatabaseService {
    // Singleton instance
    static let shared = DatabaseService()

    private var db: OpaquePointer?
    private var isInitialized = false

    // Cache for collections data
    private var cachedCollections: [ArchiveCollection]?

    // Private initializer for singleton
    private init() {}

    func openDatabase() throws {
        // If already opened, do nothing
        if isInitialized && db != nil {
            return
        }

        // Get the path to the SQLite database file
        guard let dbPath = Bundle.main.path(forResource: "identifiers", ofType: "sqlite") else {
            Logger.metadata.error("Failed to find SQLite database file")
            throw NSError(domain: "DatabaseService", code: 1, userInfo: [NSLocalizedDescriptionKey: "SQLite database file not found"])
        }

        // Open the database
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            closeDatabase()
            Logger.metadata.error("Failed to open SQLite database: \(errorMessage)")
            throw NSError(domain: "DatabaseService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to open SQLite database: \(errorMessage)"])
        }

        isInitialized = true
        Logger.metadata.debug("Successfully opened SQLite database at \(dbPath)")
    }
    
    func closeDatabase() {
        if db != nil {
            sqlite3_close(db)
            db = nil
            isInitialized = false
            cachedCollections = nil
        }
    }
    
    func loadCollections(forceReload: Bool = false) throws -> [ArchiveCollection] {
        // If we have cached collections and aren't forced to reload, return the cache
        if !forceReload, let cachedCollections = cachedCollections {
            Logger.metadata.debug("Using cached collections (\(cachedCollections.count) collections)")
            return cachedCollections
        }

        // Ensure database is open
        guard db != nil else {
            try openDatabase()
            return try loadCollections(forceReload: forceReload)
        }

        var collections: [ArchiveCollection] = []

        // Query for collections with preferred and excluded status
        let queryString = "SELECT name, preferred, excluded FROM collections"
        var queryStatement: OpaquePointer?

        if sqlite3_prepare_v2(db, queryString, -1, &queryStatement, nil) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            Logger.metadata.error("Failed to prepare collections query: \(errorMessage)")
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare query: \(errorMessage)"])
        }

        // Execute the query and process results
        while sqlite3_step(queryStatement) == SQLITE_ROW {
            if let collectionCString = sqlite3_column_text(queryStatement, 0) {
                let collectionName = String(cString: collectionCString)
                let preferred = sqlite3_column_int(queryStatement, 1) == 1
                let excluded = sqlite3_column_int(queryStatement, 2) == 1
                collections.append(ArchiveCollection(name: collectionName, preferred: preferred, excluded: excluded))
            }
        }

        // Finalize the statement
        sqlite3_finalize(queryStatement)

        if collections.isEmpty {
            Logger.metadata.error("No collections found in the database")
            throw NSError(domain: "DatabaseService", code: 4, userInfo: [NSLocalizedDescriptionKey: "No collections found in the database"])
        }

        // Update cache
        self.cachedCollections = collections
        Logger.metadata.info("Loaded \(collections.count) collections from the database, including \(collections.filter { $0.preferred }.count) preferred collections")

        return collections
    }
    
    func getAllCollections() async throws -> [ArchiveCollection] {
        // Just use the cached version
        return try loadCollections(forceReload: false)
    }
    
    func getRandomIdentifierFromEnabledCollections(_ enabledCollections: [String]) throws -> ArchiveIdentifier {
        // Ensure database is open
        guard db != nil else {
            try openDatabase()
            return try getRandomIdentifierFromEnabledCollections(enabledCollections)
        }
        
        if enabledCollections.isEmpty {
            Logger.metadata.error("No enabled collections provided")
            throw NSError(domain: "DatabaseService", code: 7, userInfo: [NSLocalizedDescriptionKey: "No enabled collections provided"])
        }
        
        // First, randomly select one of the enabled collections
        let randomIndex = Int.random(in: 0..<enabledCollections.count)
        let selectedCollection = enabledCollections[randomIndex]
        
        // Now get a random identifier from the selected collection
        let identifiers = try loadIdentifiersForCollection(selectedCollection)
        
        if identifiers.isEmpty {
            Logger.metadata.error("No identifiers found in collection \(selectedCollection)")
            throw NSError(domain: "DatabaseService", code: 8, userInfo: [NSLocalizedDescriptionKey: "No identifiers found in collection \(selectedCollection)"])
        }
        
        let randomIdentifierIndex = Int.random(in: 0..<identifiers.count)
        return identifiers[randomIdentifierIndex]
    }
    
    func loadIdentifiersForCollection(_ collection: String) throws -> [ArchiveIdentifier] {
        var identifiers: [ArchiveIdentifier] = []
        
        // Create a query to get all identifiers from the collection table
        let queryString = "SELECT identifier FROM \"\(collection)\""
        var queryStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, queryString, -1, &queryStatement, nil) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            Logger.metadata.error("Failed to prepare identifiers query for \(collection): \(errorMessage)")
            throw NSError(domain: "DatabaseService", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare query: \(errorMessage)"])
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
}