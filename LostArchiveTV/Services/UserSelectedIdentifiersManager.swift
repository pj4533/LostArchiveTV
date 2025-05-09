//
//  UserSelectedIdentifiersManager.swift
//  LostArchiveTV
//
//  Created by Claude on 5/9/25.
//

import Foundation
import OSLog

class UserSelectedIdentifiersManager {
    static let shared = UserSelectedIdentifiersManager()
    
    private let logger = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "UserSelectedIdentifiers")
    private let userDefaultsKey = "UserSelectedIdentifiers"
    
    private(set) var identifiers: [UserSelectedIdentifier] = []
    
    private init() {
        loadIdentifiers()
    }
    
    func loadIdentifiers() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            identifiers = []
            return
        }
        
        do {
            let decodedIdentifiers = try JSONDecoder().decode([UserSelectedIdentifier].self, from: data)
            identifiers = decodedIdentifiers
        } catch {
            logger.error("Failed to decode user-selected identifiers: \(error.localizedDescription)")
            identifiers = []
        }
    }
    
    func saveIdentifiers() {
        do {
            let data = try JSONEncoder().encode(identifiers)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            
            // Notify that identifiers have changed
            NotificationCenter.default.post(name: Notification.Name("ReloadIdentifiers"), object: nil)
        } catch {
            logger.error("Failed to encode user-selected identifiers: \(error.localizedDescription)")
        }
    }
    
    func addIdentifier(_ newIdentifier: UserSelectedIdentifier) {
        // Don't add duplicates
        guard !identifiers.contains(where: { $0.identifier == newIdentifier.identifier }) else {
            return
        }
        
        identifiers.append(newIdentifier)
        saveIdentifiers()
    }
    
    func removeIdentifier(withId id: String) {
        identifiers.removeAll(where: { $0.id == id })
        saveIdentifiers()
    }
    
    func contains(identifier: String) -> Bool {
        return identifiers.contains(where: { $0.identifier == identifier })
    }
    
    func getArchiveIdentifiers() -> [ArchiveIdentifier] {
        return identifiers.map { $0.archiveIdentifier }
    }
}