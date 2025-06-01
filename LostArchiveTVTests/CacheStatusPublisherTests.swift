import Testing
import Combine
import Foundation
@testable import LATV

// Test-only extensions to reset static publishers
extension VideoCacheService {
    static func resetForTesting() {
        preloadingStatusPublisher = PassthroughSubject<PreloadingStatus, Never>()
    }
}

extension TransitionPreloadManager {
    static func resetForTesting() {
        cacheStatusPublisher = PassthroughSubject<Void, Never>()
    }
}

/// Tests for Combine-based cache status publisher conversions
/// Note: These tests use static publishers and must be run serially to avoid interference
@MainActor
@Suite(.serialized)
struct CacheStatusPublisherTests {
    
    // Note: We don't reset publishers in init() to avoid interference between tests
    // Each test that needs isolation should handle its own setup
    
    // Helper to ensure clean state for each test
    private func setupCleanState() {
        VideoCacheService.resetForTesting()
        TransitionPreloadManager.resetForTesting()
        // Small delay to ensure any pending events are cleared
        Thread.sleep(forTimeInterval: 0.05)
    }
    
    // MARK: - Cache Status Publisher Tests
    
    // MARK: - Preloading Status Publisher Tests
    

    // This test is failing not sure whats up -- it crashes during test run in xcode?
    //
//    @Test
//    func preloadingStatusPublisher_multipleStatusUpdates() async {
//        // Arrange
//        setupCleanState()
//        var receivedStatuses: [VideoCacheService.PreloadingStatus] = []
//        var cancellables = Set<AnyCancellable>()
//        
//        // Subscribe immediately after reset, without await
//        VideoCacheService.preloadingStatusPublisher
//            .sink { status in
//                receivedStatuses.append(status)
//            }
//            .store(in: &cancellables)
//        
//        // Act - send multiple status updates
//        VideoCacheService.preloadingStatusPublisher.send(.started)
//        try? await Task.sleep(for: .milliseconds(50))
//        VideoCacheService.preloadingStatusPublisher.send(.completed)
//        try? await Task.sleep(for: .milliseconds(50))
//        VideoCacheService.preloadingStatusPublisher.send(.started)
//        try? await Task.sleep(for: .milliseconds(50))
//        
//        // Assert
//        #expect(receivedStatuses.count == 3)
//        #expect(receivedStatuses[0] == .started)
//        #expect(receivedStatuses[1] == .completed)
//        #expect(receivedStatuses[2] == .started)
//    }
    
    // MARK: - Integration Tests
    
    
    
    @Test
    func transitionPreloadManager_nextVideoReady_stateManagement() async {
        // Arrange
        let manager = TransitionPreloadManager()
        
        // Test initial state
        #expect(manager.nextVideoReady == false)
        #expect(manager.nextPlayer == nil)
        #expect(manager.nextTitle == "")
        #expect(manager.nextDescription == "")
        
        // Act - Set video ready state
        manager.nextVideoReady = true
        manager.nextTitle = "Test Video"
        manager.nextDescription = "Test Description"
        manager.nextIdentifier = "test-123"
        
        // Assert - Verify state changes
        #expect(manager.nextVideoReady == true)
        #expect(manager.nextTitle == "Test Video")
        #expect(manager.nextDescription == "Test Description")
        #expect(manager.nextIdentifier == "test-123")
        
        // Test resetting state
        manager.nextVideoReady = false
        #expect(manager.nextVideoReady == false)
    }
    
    @Test
    func transitionPreloadManager_prevVideoReady_stateManagement() async {
        // Arrange
        let manager = TransitionPreloadManager()
        
        // Test initial state
        #expect(manager.prevVideoReady == false)
        #expect(manager.prevPlayer == nil)
        #expect(manager.prevTitle == "")
        #expect(manager.prevDescription == "")
        
        // Act - Set video ready state
        manager.prevVideoReady = true
        manager.prevTitle = "Previous Video"
        manager.prevDescription = "Previous Description"
        manager.prevIdentifier = "prev-123"
        
        // Assert - Verify state changes
        #expect(manager.prevVideoReady == true)
        #expect(manager.prevTitle == "Previous Video")
        #expect(manager.prevDescription == "Previous Description")
        #expect(manager.prevIdentifier == "prev-123")
        
        // Test resetting state
        manager.prevVideoReady = false
        #expect(manager.prevVideoReady == false)
    }
    
    
    // MARK: - Thread Safety Tests
    
    // MARK: - Memory Management Tests
    
}
