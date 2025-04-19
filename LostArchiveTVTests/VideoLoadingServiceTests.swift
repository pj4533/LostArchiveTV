//
//  VideoLoadingServiceTests.swift
//  LostArchiveTVTests
//
//  Created by Claude on 4/19/25.
//

import Testing
import AVKit
@testable import LostArchiveTV

struct VideoLoadingServiceTests {
    
    // Since we can't easily mock the service dependencies without modifying the app code
    // to support dependency injection, we'll test with the real implementations
    
    @Test
    func loadIdentifiers_returnsNonEmptyArray() async throws {
        // Arrange
        let archiveService = ArchiveService()
        let cacheManager = VideoCacheManager()
        let videoLoadingService = VideoLoadingService(
            archiveService: archiveService,
            cacheManager: cacheManager
        )
        
        // Act
        let identifiers = try await videoLoadingService.loadIdentifiers()
        
        // Assert - should load from the actual json file
        #expect(!identifiers.isEmpty)
    }
    
    @Test
    func loadRandomVideo_whenCacheEmpty_loadsFreshVideo() async throws {
        // Arrange
        let archiveService = ArchiveService()
        let cacheManager = VideoCacheManager()
        let videoLoadingService = VideoLoadingService(
            archiveService: archiveService,
            cacheManager: cacheManager
        )
        
        // Clear cache to ensure we load a fresh video
        await cacheManager.clearCache()
        
        // Act
        let video = try await videoLoadingService.loadRandomVideo()
        
        // Assert - we can't know exactly what video will be loaded, but can check structure
        #expect(video.identifier.isEmpty == false)
        #expect(video.asset is AVURLAsset)
        #expect(video.startPosition >= 0)
        
        // The title and description might be nil depending on the metadata, so we don't assert on those
    }
}