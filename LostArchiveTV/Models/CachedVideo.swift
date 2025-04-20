//
//  CachedVideo.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import Foundation
import AVKit

struct CachedVideo {
    let identifier: String
    let collection: String
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
}