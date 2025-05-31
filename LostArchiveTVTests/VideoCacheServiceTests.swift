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
    
    // MARK: - Notification Tests (Phase 1 Baseline)
    
    @Test
    func notifyCachingStarted_postsPreloadingStartedNotification() async {
        // Arrange
        let cacheService = VideoCacheService()
        var receivedNotification = false
        var cancellables = Set<AnyCancellable>()
        
        // Subscribe to notification
        await MainActor.run {
            NotificationCenter.default
                .publisher(for: .preloadingStarted)
                .sink { _ in
                    receivedNotification = true
                }
                .store(in: &cancellables)
        }
        
        // Act
        await cacheService.notifyCachingStarted()
        
        // Wait for notification to be posted
        try? await Task.sleep(for: .milliseconds(100))
        
        // Assert
        await MainActor.run {
            #expect(receivedNotification == true)
        }
    }
    
    @Test
    func notifyCachingCompleted_postsPreloadingCompletedNotification() async {
        // Arrange
        let cacheService = VideoCacheService()
        var receivedNotification = false
        var cancellables = Set<AnyCancellable>()
        
        // Subscribe to notification
        await MainActor.run {
            NotificationCenter.default
                .publisher(for: .preloadingCompleted)
                .sink { _ in
                    receivedNotification = true
                }
                .store(in: &cancellables)
        }
        
        // Act
        await cacheService.notifyCachingCompleted()
        
        // Wait for notification to be posted
        try? await Task.sleep(for: .milliseconds(100))
        
        // Assert
        await MainActor.run {
            #expect(receivedNotification == true)
        }
    }
    
    @Test
    func cachingNotifications_arePostedOnMainThread() async {
        // Arrange
        let cacheService = VideoCacheService()
        var startedOnMainThread = false
        var completedOnMainThread = false
        var cancellables = Set<AnyCancellable>()
        
        // Subscribe to notifications
        await MainActor.run {
            NotificationCenter.default
                .publisher(for: .preloadingStarted)
                .sink { _ in
                    startedOnMainThread = Thread.isMainThread
                }
                .store(in: &cancellables)
            
            NotificationCenter.default
                .publisher(for: .preloadingCompleted)
                .sink { _ in
                    completedOnMainThread = Thread.isMainThread
                }
                .store(in: &cancellables)
        }
        
        // Act
        await cacheService.notifyCachingStarted()
        await cacheService.notifyCachingCompleted()
        
        // Wait for notifications
        try? await Task.sleep(for: .milliseconds(100))
        
        // Assert
        await MainActor.run {
            #expect(startedOnMainThread == true)
            #expect(completedOnMainThread == true)
        }
    }
    
    @Test
    func multipleSubscribers_allReceiveNotifications() async {
        // Arrange
        let cacheService = VideoCacheService()
        var subscriber1Received = false
        var subscriber2Received = false
        var subscriber3Received = false
        var cancellables = Set<AnyCancellable>()
        
        // Create multiple subscribers
        await MainActor.run {
            NotificationCenter.default
                .publisher(for: .preloadingStarted)
                .sink { _ in subscriber1Received = true }
                .store(in: &cancellables)
            
            NotificationCenter.default
                .publisher(for: .preloadingStarted)
                .sink { _ in subscriber2Received = true }
                .store(in: &cancellables)
            
            NotificationCenter.default
                .publisher(for: .preloadingStarted)
                .sink { _ in subscriber3Received = true }
                .store(in: &cancellables)
        }
        
        // Act
        await cacheService.notifyCachingStarted()
        
        // Wait for notifications
        try? await Task.sleep(for: .milliseconds(100))
        
        // Assert
        await MainActor.run {
            #expect(subscriber1Received == true)
            #expect(subscriber2Received == true)
            #expect(subscriber3Received == true)
        }
    }
}