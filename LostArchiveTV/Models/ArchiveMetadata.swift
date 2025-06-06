//
//  ArchiveMetadata.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import Foundation

struct ArchiveMetadata: Codable {
    let files: [ArchiveFile]
    let metadata: ItemMetadata?
}
