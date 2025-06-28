//
//  ArchiveIdentifier.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import Foundation

struct ArchiveIdentifier: Codable, Equatable, Sendable {
    let identifier: String
    let collection: String
}