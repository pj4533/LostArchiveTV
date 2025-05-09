//
//  UserSelectedIdentifier.swift
//  LostArchiveTV
//
//  Created by Claude on 5/9/25.
//

import Foundation

struct UserSelectedIdentifier: Codable, Identifiable, Equatable {
    let id: String // Same as identifier
    let identifier: String
    let title: String
    let collection: String
    let fileCount: Int
    
    var archiveIdentifier: ArchiveIdentifier {
        return ArchiveIdentifier(identifier: identifier, collection: collection)
    }
    
    static func == (lhs: UserSelectedIdentifier, rhs: UserSelectedIdentifier) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}