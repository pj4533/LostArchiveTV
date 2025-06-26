//
//  SimilarVideo.swift
//  LostArchiveTV
//
//  Created by Claude on 6/26/25.
//

import Foundation

/// Model representing a video for similar videos navigation
struct SimilarVideo: Equatable, Sendable {
    let identifier: String
    let title: String
    let description: String
    let thumbnailURL: URL
    let fileCount: Int
    
    init(identifier: String, title: String, description: String, thumbnailURL: URL, fileCount: Int = 1) {
        self.identifier = identifier
        self.title = title
        self.description = description
        self.thumbnailURL = thumbnailURL
        self.fileCount = fileCount
    }
}