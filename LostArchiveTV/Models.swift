//
//  Models.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import Foundation
import AVKit

// MARK: - Archive Models
struct ArchiveIdentifier: Codable {
    let identifier: String
}

struct ArchiveMetadata: Codable {
    let files: [ArchiveFile]
    let metadata: ItemMetadata?
}

struct ItemMetadata: Codable {
    let identifier: String?
    let title: String?
    let description: String?
}

struct ArchiveFile: Codable {
    let name: String
    let format: String?
    let size: String?
    let length: String?
}

// MARK: - Cached Video
struct CachedVideo {
    let identifier: String
    let metadata: ArchiveMetadata
    let mp4File: ArchiveFile
    let videoURL: URL
    let asset: AVURLAsset
    let playerItem: AVPlayerItem
    let startPosition: Double
    
    var title: String {
        metadata.metadata?.title ?? identifier
    }
    
    var description: String {
        metadata.metadata?.description ?? "Internet Archive random video clip"
    }
    
    var player: AVPlayer {
        AVPlayer(playerItem: playerItem)
    }
}
