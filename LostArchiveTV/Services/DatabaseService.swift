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
    private var db: OpaquePointer?
    
    func openDatabase() throws {
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
        
        Logger.metadata.debug("Successfully opened SQLite database at \(dbPath)")
    }
    
    func closeDatabase() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }
    
    func loadCollections() throws -> [ArchiveCollection] {
        // Ensure database is open
        guard db != nil else {
            try openDatabase()
            return try loadCollections()
        }
        
        var collections: [ArchiveCollection] = []
        
        // Query for collections with preferred status
        let queryString = "SELECT name, preferred FROM collections"
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
                collections.append(ArchiveCollection(name: collectionName, preferred: preferred))
            }
        }
        
        // Finalize the statement
        sqlite3_finalize(queryStatement)
        
        if collections.isEmpty {
            Logger.metadata.error("No collections found in the database")
            throw NSError(domain: "DatabaseService", code: 4, userInfo: [NSLocalizedDescriptionKey: "No collections found in the database"])
        }
        
        return collections
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