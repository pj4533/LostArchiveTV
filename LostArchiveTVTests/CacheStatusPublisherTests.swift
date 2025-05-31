import Testing
import Combine
import Foundation
@testable import LATV

/// Tests for Combine-based cache status publisher conversions
@MainActor
struct CacheStatusPublisherTests {
    
    // MARK: - Cache Status Publisher Tests
    
    @Test
    func cacheStatusPublisher_receivesUpdates() async {
        // Arrange
        var receivedUpdate = false
        var cancellables = Set<AnyCancellable>()
        
        TransitionPreloadManager.cacheStatusPublisher
            .sink { _ in
                receivedUpdate = true
            }
            .store(in: &cancellables)
        
        // Act - simulate cache status change
        TransitionPreloadManager.cacheStatusPublisher.send()
        
        // Wait briefly
        try? await Task.sleep(for: .milliseconds(50))
        
        // Assert
        #expect(receivedUpdate == true)
    }
    
    @Test
    func cacheStatusPublisher_multipleSubscribersReceiveUpdates() async {
        // Arrange
        var subscriber1Received = false
        var subscriber2Received = false
        var subscriber3Received = false
        var cancellables = Set<AnyCancellable>()
        
        // Create multiple subscribers
        TransitionPreloadManager.cacheStatusPublisher
            .sink { _ in subscriber1Received = true }
            .store(in: &cancellables)
        
        TransitionPreloadManager.cacheStatusPublisher
            .sink { _ in subscriber2Received = true }
            .store(in: &cancellables)
        
        TransitionPreloadManager.cacheStatusPublisher
            .sink { _ in subscriber3Received = true }
            .store(in: &cancellables)
        
        // Act
        TransitionPreloadManager.cacheStatusPublisher.send()
        
        // Wait briefly
        try? await Task.sleep(for: .milliseconds(50))
        
        // Assert - all subscribers should receive
        #expect(subscriber1Received == true)
        #expect(subscriber2Received == true)
        #expect(subscriber3Received == true)
    }
    
    // MARK: - Preloading Status Publisher Tests
    
    @Test
    func preloadingStatusPublisher_receivesStartedStatus() async {
        // Arrange
        var receivedStatus: VideoCacheService.PreloadingStatus?
        var cancellables = Set<AnyCancellable>()
        
        VideoCacheService.preloadingStatusPublisher
            .sink { status in
                receivedStatus = status
            }
            .store(in: &cancellables)
        
        // Act
        VideoCacheService.preloadingStatusPublisher.send(.started)
        
        // Wait briefly
        try? await Task.sleep(for: .milliseconds(50))
        
        // Assert
        #expect(receivedStatus == .started)
    }
    
    @Test
    func preloadingStatusPublisher_receivesCompletedStatus() async {
        // Arrange
        var receivedStatus: VideoCacheService.PreloadingStatus?
        var cancellables = Set<AnyCancellable>()
        
        VideoCacheService.preloadingStatusPublisher
            .sink { status in
                receivedStatus = status
            }
            .store(in: &cancellables)
        
        // Act
        VideoCacheService.preloadingStatusPublisher.send(.completed)
        
        // Wait briefly
        try? await Task.sleep(for: .milliseconds(50))
        
        // Assert
        #expect(receivedStatus == .completed)
    }
    
    @Test
    func preloadingStatusPublisher_multipleStatusUpdates() async {
        // Arrange
        var receivedStatuses: [VideoCacheService.PreloadingStatus] = []
        var cancellables = Set<AnyCancellable>()
        
        VideoCacheService.preloadingStatusPublisher
            .sink { status in
                receivedStatuses.append(status)
            }
            .store(in: &cancellables)
        
        // Act - send multiple status updates
        VideoCacheService.preloadingStatusPublisher.send(.started)
        try? await Task.sleep(for: .milliseconds(50))
        VideoCacheService.preloadingStatusPublisher.send(.completed)
        try? await Task.sleep(for: .milliseconds(50))
        VideoCacheService.preloadingStatusPublisher.send(.started)
        try? await Task.sleep(for: .milliseconds(50))
        
        // Assert
        #expect(receivedStatuses.count == 3)
        #expect(receivedStatuses[0] == .started)
        #expect(receivedStatuses[1] == .completed)
        #expect(receivedStatuses[2] == .started)
    }
    
    // MARK: - Integration Tests
    
    @Test
    func cacheService_notifyCachingStarted_sendsPublisherEvent() async {
        // Arrange
        let cacheService = VideoCacheService()
        var receivedStatus: VideoCacheService.PreloadingStatus?
        var cancellables = Set<AnyCancellable>()
        
        VideoCacheService.preloadingStatusPublisher
            .sink { status in
                receivedStatus = status
            }
            .store(in: &cancellables)
        
        // Act
        await cacheService.notifyCachingStarted()
        
        // Wait for async notification
        try? await Task.sleep(for: .milliseconds(100))
        
        // Assert
        #expect(receivedStatus == .started)
    }
    
    @Test
    func cacheService_notifyCachingCompleted_sendsPublisherEvent() async {
        // Arrange
        let cacheService = VideoCacheService()
        var receivedStatus: VideoCacheService.PreloadingStatus?
        var cancellables = Set<AnyCancellable>()
        
        VideoCacheService.preloadingStatusPublisher
            .sink { status in
                receivedStatus = status
            }
            .store(in: &cancellables)
        
        // Act
        await cacheService.notifyCachingCompleted()
        
        // Wait for async notification
        try? await Task.sleep(for: .milliseconds(100))
        
        // Assert
        #expect(receivedStatus == .completed)
    }
    
    @Test
    func transitionPreloadManager_nextVideoReadyChange_sendsPublisherEvent() async {
        // Arrange
        let manager = TransitionPreloadManager()
        var receivedUpdate = false
        var cancellables = Set<AnyCancellable>()
        
        TransitionPreloadManager.cacheStatusPublisher
            .sink { _ in
                receivedUpdate = true
            }
            .store(in: &cancellables)
        
        // Act - change nextVideoReady
        manager.nextVideoReady = true
        
        // Wait for async notification
        try? await Task.sleep(for: .milliseconds(100))
        
        // Assert
        #expect(receivedUpdate == true)
    }
    
    @Test
    func transitionPreloadManager_prevVideoReadyChange_sendsPublisherEvent() async {
        // Arrange
        let manager = TransitionPreloadManager()
        var receivedUpdate = false
        var cancellables = Set<AnyCancellable>()
        
        TransitionPreloadManager.cacheStatusPublisher
            .sink { _ in
                receivedUpdate = true
            }
            .store(in: &cancellables)
        
        // Act - change prevVideoReady
        manager.prevVideoReady = true
        
        // Wait for async notification
        try? await Task.sleep(for: .milliseconds(100))
        
        // Assert
        #expect(receivedUpdate == true)
    }
    
    
    // MARK: - Thread Safety Tests
    
    @Test
    func concurrentPublisherEvents_handleGracefully() async {
        // Arrange
        var eventCount = 0
        var cancellables = Set<AnyCancellable>()
        
        TransitionPreloadManager.cacheStatusPublisher
            .sink { _ in
                eventCount += 1
            }
            .store(in: &cancellables)
        
        // Act - send multiple events concurrently
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    TransitionPreloadManager.cacheStatusPublisher.send()
                }
            }
        }
        
        // Wait for all events
        try? await Task.sleep(for: .milliseconds(200))
        
        // Assert - all events should be received
        #expect(eventCount == 10)
    }
    
    // MARK: - Memory Management Tests
    
    @Test
    func publisherSubscription_properlyCleanedUp() async {
        // Arrange
        var receivedUpdate = false
        var cancellables = Set<AnyCancellable>()
        
        TransitionPreloadManager.cacheStatusPublisher
            .sink { _ in
                receivedUpdate = true
            }
            .store(in: &cancellables)
        
        // Act - clear cancellables
        cancellables.removeAll()
        
        // Send an update after clearing
        TransitionPreloadManager.cacheStatusPublisher.send()
        
        // Wait briefly
        try? await Task.sleep(for: .milliseconds(50))
        
        // Assert - should not receive update after cancellation
        #expect(receivedUpdate == false)
    }
}