//
//  CachedVideoTests.swift
//  LostArchiveTVTests
//
//  Created by Claude on 5/2/25.
//

import Testing
import AVKit
@testable import LATV

struct CachedVideoTests {
    
    // Helper function to create a test video
    func createTestVideo(
        identifier: String = "test123",
        collection: String = "testCollection",
        title: String? = "Test Title",
        description: String? = "Test Description",
        timestamp: Date? = nil
    ) -> CachedVideo {
        let url = URL(string: "https://example.com/test/\(identifier).mp4")!
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        
        let metadata = ArchiveMetadata(
            files: [],
            metadata: ItemMetadata(
                identifier: identifier,
                title: title,
                description: description
            )
        )
        
        let mp4File = ArchiveFile(
            name: "\(identifier).mp4",
            format: "MPEG4",
            size: "1000",
            length: "120"
        )
        
        return CachedVideo(
            identifier: identifier,
            collection: collection,
            metadata: metadata,
            mp4File: mp4File,
            videoURL: url,
            asset: asset,
            playerItem: playerItem,
            startPosition: 0.0,
            addedToFavoritesAt: timestamp,
            totalFiles: 1
        )
    }
    
    @Test
    func title_usesMetadataTitleWhenAvailable() {
        // Arrange
        let video = createTestVideo(identifier: "test123", title: "Custom Title")
        
        // Act
        let title = video.title
        
        // Assert
        #expect(title == "Custom Title")
    }
    
    @Test
    func title_usesIdentifierWhenTitleIsNil() {
        // Arrange
        let video = createTestVideo(identifier: "test123", title: nil)
        
        // Act
        let title = video.title
        
        // Assert
        #expect(title == "test123")
    }
    
    @Test
    func description_usesMetadataDescriptionWhenAvailable() {
        // Arrange
        let video = createTestVideo(identifier: "test123", description: "Custom Description")
        
        // Act
        let description = video.description
        
        // Assert
        #expect(description == "Custom Description")
    }
    
    @Test
    func description_usesDefaultWhenDescriptionIsNil() {
        // Arrange
        let video = createTestVideo(identifier: "test123", description: nil)
        
        // Act
        let description = video.description
        
        // Assert
        #expect(description == "Internet Archive random video clip")
    }
    
    @Test
    func thumbnailURL_constructsCorrectURL() {
        // Arrange
        let video = createTestVideo(identifier: "test123")
        
        // Act
        let thumbnailURL = video.thumbnailURL
        
        // Assert
        #expect(thumbnailURL != nil)
        #expect(thumbnailURL?.absoluteString == "https://archive.org/services/img/test123")
    }
    
    @Test
    func equatable_comparesByIdentifier() {
        // Arrange
        let video1 = createTestVideo(identifier: "test123", title: "First Video")
        let video2 = createTestVideo(identifier: "test123", title: "Second Video")
        let video3 = createTestVideo(identifier: "test456", title: "Third Video")
        
        // Assert
        #expect(video1 == video2) // Same identifier, different titles
        #expect(video1 != video3) // Different identifiers
    }
    
    @Test
    func id_returnsIdentifier() {
        // Arrange
        let video = createTestVideo(identifier: "test123")
        
        // Act
        let id = video.id
        
        // Assert
        #expect(id == "test123")
    }
}