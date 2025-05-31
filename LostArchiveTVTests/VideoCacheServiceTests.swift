//
//  VideoCacheServiceTests.swift
//  LostArchiveTVTests
//
//  Created by Claude on 4/19/25.
//

import Testing
import AVKit
@testable import LATV

struct VideoCacheServiceTests {
    // Most of VideoCacheService's functionality requires complex interactions
    // between live ArchiveService and VideoCacheManager, so only basic tests are possible
    
    @Test
    func ensureVideosAreCached_withEmptyIdentifiers_doesNotLoadVideos() async {
        // Arrange
        let cacheService = VideoCacheService()
        let cacheManager = VideoCacheManager()
        let archiveService = ArchiveService()
        let identifiers: [ArchiveIdentifier] = []
        
        // Act
        await cacheService.ensureVideosAreCached(
            cacheManager: cacheManager,
            archiveService: archiveService,
            identifiers: identifiers
        )
        
        // Assert - only verify no videos were added to cache
        let cacheCount = await cacheManager.cacheCount()
        #expect(cacheCount == 0)
        
        // Since we can't easily inject mocks without dependency injection,
        // we're just confirming the function doesn't crash with empty identifiers
    }
    
    @Test
    func cancelCaching_doesNotCrash() async {
        // Arrange
        let cacheService = VideoCacheService()
        
        // Act & Assert - just verifying the function can be called without errors
        await cacheService.cancelCaching()
        #expect(true)
    }
}