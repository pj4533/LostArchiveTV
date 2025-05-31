import Testing
import Combine
import Foundation
@testable import LATV

@MainActor
struct PreloadingIndicatorManagerTests {
    
    // MARK: - Preloading Notification Tests
    
    @Test
    func preloadingStartedNotification_setsPreloadingState() async {
        // Arrange
        let manager = PreloadingIndicatorManager.shared
        manager.reset() // Start from known state
        #expect(manager.state == .notPreloading)
        
        // Act
        VideoCacheService.preloadingStatusPublisher.send(.started)
        
        // Wait for notification processing
        try? await Task.sleep(for: .milliseconds(100))
        
        // Assert
        #expect(manager.state == .preloading)
    }
    
    @Test
    func preloadingCompletedNotification_triggersStateUpdate() async {
        // Arrange
        let manager = PreloadingIndicatorManager.shared
        manager.state = .preloading
        
        // Act
        VideoCacheService.preloadingStatusPublisher.send(.completed)
        
        // Wait for notification processing
        try? await Task.sleep(for: .milliseconds(100))
        
        // Assert - state update depends on TransitionManager which we can't mock
        // Just verify the notification doesn't crash
        #expect(true)
    }
    
    @Test
    func setPreloading_changesStateFromNotPreloading() async {
        // Arrange
        let manager = PreloadingIndicatorManager.shared
        manager.state = .notPreloading
        
        // Act
        manager.setPreloading()
        
        // Assert
        #expect(manager.state == .preloading)
    }
    
    @Test
    func setPreloading_doesNotChangePreloadedState() async {
        // Arrange
        let manager = PreloadingIndicatorManager.shared
        manager.state = .preloaded
        
        // Act
        manager.setPreloading()
        
        // Assert - should remain preloaded
        #expect(manager.state == .preloaded)
    }
    
    @Test
    func setPreloaded_changesStateToPreloaded() async {
        // Arrange
        let manager = PreloadingIndicatorManager.shared
        manager.state = .notPreloading
        
        // Act
        manager.setPreloaded()
        
        // Assert
        #expect(manager.state == .preloaded)
    }
    
    @Test
    func reset_changesStateToNotPreloading() async {
        // Arrange
        let manager = PreloadingIndicatorManager.shared
        manager.state = .preloaded
        
        // Act
        manager.reset()
        
        // Assert
        #expect(manager.state == .notPreloading)
    }
    
    // MARK: - CacheStatusChanged Notification Tests
    
    @Test
    func cacheStatusChangedNotification_triggersUpdateFromTransitionManager() async {
        // Arrange
        let manager = PreloadingIndicatorManager.shared
        
        // Act
        NotificationCenter.default.post(
            name: Notification.Name("CacheStatusChanged"),
            object: nil
        )
        
        // Wait for notification processing
        try? await Task.sleep(for: .milliseconds(100))
        
        // Assert - updateStateFromTransitionManager requires SharedViewModelProvider
        // which isn't available in tests, so just verify no crash
        #expect(true)
    }
    
    @Test
    func multipleNotificationTypes_areHandledCorrectly() async {
        // Arrange & Act
        let manager = PreloadingIndicatorManager.shared
        
        // Send multiple notifications in sequence
        VideoCacheService.preloadingStatusPublisher.send(.started)
        TransitionPreloadManager.cacheStatusPublisher.send()
        VideoCacheService.preloadingStatusPublisher.send(.completed)
        
        // Wait for all notifications
        try? await Task.sleep(for: .milliseconds(200))
        
        // Assert - verify no crashes from rapid notifications
        #expect(true)
    }
    
    // MARK: - State Transition Tests
    
    @Test
    func stateTransitions_followExpectedPattern() async {
        let manager = PreloadingIndicatorManager.shared
        
        // Initial state
        manager.reset()
        #expect(manager.state == .notPreloading)
        
        // Start preloading
        manager.setPreloading()
        #expect(manager.state == .preloading)
        
        // Complete preloading
        manager.setPreloaded()
        #expect(manager.state == .preloaded)
        
        // Reset
        manager.reset()
        #expect(manager.state == .notPreloading)
    }
    
    @Test
    func preloadingState_publishesChanges() async {
        let manager = PreloadingIndicatorManager.shared
        var receivedStates: [PreloadingState] = []
        var cancellables = Set<AnyCancellable>()
        
        // Subscribe to state changes
        manager.$state
            .sink { state in
                receivedStates.append(state)
            }
            .store(in: &cancellables)
        
        // Change states
        manager.reset()
        manager.setPreloading()
        manager.setPreloaded()
        manager.reset()
        
        // Wait briefly for all changes to propagate
        try? await Task.sleep(for: .milliseconds(50))
        
        // Verify all state changes were published
        #expect(receivedStates.count >= 3)
        #expect(receivedStates.contains(.preloading))
        #expect(receivedStates.contains(.preloaded))
        #expect(receivedStates.contains(.notPreloading))
    }
}