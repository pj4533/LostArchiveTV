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
    
    // MARK: - Permanently Failed Identifier Tests
    
    @Test
    func markAsPermanentlyFailed_withValidIdentifier_addsToFailedSet() async {
        // Arrange
        let cacheService = VideoCacheService()
        let identifier = "test-video-123"
        let collection = "test-collection"
        
        // Act
        await cacheService.markAsPermanentlyFailed(identifier: identifier, collection: collection)
        
        // Assert
        let isMarkedAsFailed = await cacheService.isIdentifierPermanentlyFailed(identifier)
        #expect(isMarkedAsFailed == true)
    }
    
    @Test
    func markAsPermanentlyFailed_withNilIdentifier_doesNotCrash() async {
        // Arrange
        let cacheService = VideoCacheService()
        
        // Act
        await cacheService.markAsPermanentlyFailed(identifier: nil, collection: "test-collection")
        
        // Assert - just verify no crash
        #expect(true)
    }
    
    @Test
    func markAsPermanentlyFailed_multipleIdentifiers_tracksAllIdentifiers() async {
        // Arrange
        let cacheService = VideoCacheService()
        let identifiers = ["video-1", "video-2", "video-3"]
        
        // Act
        for identifier in identifiers {
            await cacheService.markAsPermanentlyFailed(identifier: identifier)
        }
        
        // Assert
        for identifier in identifiers {
            let isFailed = await cacheService.isIdentifierPermanentlyFailed(identifier)
            #expect(isFailed == true)
        }
        
        let failedSet = await cacheService.getPermanentlyFailedIdentifiers()
        #expect(failedSet.count == 3)
    }
    
    @Test
    func isIdentifierPermanentlyFailed_withUnmarkedIdentifier_returnsFalse() async {
        // Arrange
        let cacheService = VideoCacheService()
        let identifier = "unmarked-video-123"
        
        // Act
        let isFailed = await cacheService.isIdentifierPermanentlyFailed(identifier)
        
        // Assert
        #expect(isFailed == false)
    }
    
    @Test
    func clearPermanentlyFailedIdentifiers_removesAllFailedIdentifiers() async {
        // Arrange
        let cacheService = VideoCacheService()
        let identifiers = ["video-1", "video-2", "video-3"]
        
        // Mark identifiers as failed
        for identifier in identifiers {
            await cacheService.markAsPermanentlyFailed(identifier: identifier)
        }
        
        // Verify they are marked as failed
        let failedSetBefore = await cacheService.getPermanentlyFailedIdentifiers()
        #expect(failedSetBefore.count == 3)
        
        // Act
        await cacheService.clearPermanentlyFailedIdentifiers()
        
        // Assert
        let failedSetAfter = await cacheService.getPermanentlyFailedIdentifiers()
        #expect(failedSetAfter.count == 0)
        
        // Verify individual identifiers are no longer failed
        for identifier in identifiers {
            let isFailed = await cacheService.isIdentifierPermanentlyFailed(identifier)
            #expect(isFailed == false)
        }
    }
    
    @Test
    func getPermanentlyFailedIdentifiers_returnsCorrectSet() async {
        // Arrange
        let cacheService = VideoCacheService()
        let expectedIdentifiers = Set(["video-1", "video-2", "video-3"])
        
        // Act
        for identifier in expectedIdentifiers {
            await cacheService.markAsPermanentlyFailed(identifier: identifier)
        }
        
        // Assert
        let failedIdentifiers = await cacheService.getPermanentlyFailedIdentifiers()
        #expect(failedIdentifiers == expectedIdentifiers)
    }
    
    @Test
    func markAsPermanentlyFailed_duplicateIdentifier_doesNotDuplicate() async {
        // Arrange
        let cacheService = VideoCacheService()
        let identifier = "duplicate-video-123"
        
        // Act - mark the same identifier multiple times
        await cacheService.markAsPermanentlyFailed(identifier: identifier)
        await cacheService.markAsPermanentlyFailed(identifier: identifier)
        await cacheService.markAsPermanentlyFailed(identifier: identifier)
        
        // Assert
        let failedSet = await cacheService.getPermanentlyFailedIdentifiers()
        #expect(failedSet.count == 1)
        #expect(failedSet.contains(identifier) == true)
    }
    
}