//
//  ArchiveFile.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import Foundation

struct ArchiveFile: Codable, Sendable {
    let name: String
    let format: String?
    let size: String?
    let length: String?
}
