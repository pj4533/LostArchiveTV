//
//  VideoCacheServiceTests.swift
//  LostArchiveTVTests
//
//  Created by Claude on 4/19/25.
//

import Testing
import AVKit
import Combine
@testable import LATV

@MainActor
@Suite(.serialized)
struct VideoCacheServiceTests {
    // Most of VideoCacheService's functionality requires complex interactions
    // between live ArchiveService and VideoCacheManager, so only basic tests are possible
    
    // Helper to ensure clean state for each test
    private func setupCleanState() async {
        VideoCacheService.resetForTesting()
        TransitionPreloadManager.resetForTesting()
        // Small delay to ensure any pending async operations complete
        try? await Task.sleep(for: .milliseconds(50))
    }
    
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
    
    // MARK: - Notification Tests (Phase 1 Baseline)
    
    @Test
    func cacheOperations_completeSafely() async {
        // Arrange
        let cacheService = VideoCacheService()
        
        // Test basic operations complete without crash
        
        // Act 1: Cancel caching when nothing is running
        await cacheService.cancelCaching()
        
        // Act 2: Start and stop notification cycle
        await cacheService.notifyCachingStarted()
        await cacheService.notifyCachingCompleted()
        
        // Assert - operations complete without error
        #expect(true)
    }
    
    @Test
    func cancelCaching_handlesMultipleCalls() async {
        // Arrange
        let cacheService = VideoCacheService()
        
        // Act - verify that calling cancel multiple times doesn't cause issues
        await cacheService.cancelCaching()
        await cacheService.cancelCaching()
        await cacheService.cancelCaching()
        
        // Assert - just verify no crash
        #expect(true)
    }
    
}