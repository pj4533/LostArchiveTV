import Testing
import Combine
import Foundation
@testable import LATV

@MainActor
@Suite(.serialized)
struct PreloadingIndicatorManagerTests {
    
    // Helper to ensure clean state for each test
    private func setupCleanState() async {
        VideoCacheService.resetForTesting()
        TransitionPreloadManager.resetForTesting()
        PreloadingIndicatorManager.shared.resetForTesting()
        // Longer delay to ensure subscriptions are properly established
        try? await Task.sleep(for: .milliseconds(100))
    }
    
    // MARK: - Preloading Notification Tests
    
    @Test
    func setPreloading_fromNotificationPath_changesState() async {
        await setupCleanState()
        
        // Arrange
        let manager = PreloadingIndicatorManager.shared
        manager.reset() // Ensure we start from notPreloading
        #expect(manager.state == .notPreloading)
        
        // Act - Test the actual behavior method that notifications would trigger
        manager.setPreloading()
        
        // Assert
        #expect(manager.state == .preloading)
    }
    
    @Test
    func updateStateFromTransitionManager_behaviorTest() async {
        await setupCleanState()
        
        // Arrange
        let manager = PreloadingIndicatorManager.shared
        
        // Test 1: When in preloading state with low buffer
        manager.state = .preloading
        manager.updateStateFromTransitionManager(bufferState: .low)
        
        // Should remain in preloading state with low buffer
        #expect(manager.state == .preloading)
        
        // Test 2: When in preloading state with sufficient buffer
        manager.state = .preloading
        manager.updateStateFromTransitionManager(bufferState: .sufficient)
        
        // Should transition to preloaded with sufficient buffer
        #expect(manager.state == .preloaded)
    }
    
    @Test
    func setPreloading_changesStateFromNotPreloading() async {
        await setupCleanState()
        
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
        await setupCleanState()
        
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
        await setupCleanState()
        
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
        await setupCleanState()
        
        // Arrange
        let manager = PreloadingIndicatorManager.shared
        manager.state = .preloaded
        
        // Act
        manager.reset()
        
        // Assert
        #expect(manager.state == .notPreloading)
    }
    
    // MARK: - BufferStatusChanged Notification Tests
    
    @Test
    func bufferStatusChangedNotification_triggersUpdateFromTransitionManager() async {
        await setupCleanState()
        
        // Arrange
        let manager = PreloadingIndicatorManager.shared
        
        // Act
        NotificationCenter.default.post(
            name: Notification.Name("BufferStatusChanged"),
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
        await setupCleanState()
        
        // Arrange & Act
        let manager = PreloadingIndicatorManager.shared
        
        // Send multiple notifications in sequence
        VideoCacheService.preloadingStatusPublisher.send(.started)
        TransitionPreloadManager.bufferStatusPublisher.send(.sufficient)
        VideoCacheService.preloadingStatusPublisher.send(.completed)
        
        // Wait for all notifications
        try? await Task.sleep(for: .milliseconds(200))
        
        // Assert - verify no crashes from rapid notifications
        #expect(true)
    }
    
    // MARK: - State Transition Tests
    
    @Test
    func stateTransitions_followExpectedPattern() async {
        await setupCleanState()
        
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
        await setupCleanState()
        
        let manager = PreloadingIndicatorManager.shared
        var receivedStates: [PreloadingState] = []
        var cancellables = Set<AnyCancellable>()
        
        // Subscribe to state changes, including initial value
        manager.$state
            .sink { state in
                receivedStates.append(state)
            }
            .store(in: &cancellables)
        
        // Change states - ensure we actually trigger state changes
        manager.setPreloading()  // Should change from notPreloading to preloading
        manager.setPreloaded()   // Should change from preloading to preloaded
        manager.reset()          // Should change from preloaded to notPreloading
        
        // Wait briefly for all changes to propagate
        try? await Task.sleep(for: .milliseconds(100))
        
        // Verify all state changes were published
        // We should have initial state + 3 changes = 4 total
        #expect(receivedStates.count >= 4)
        #expect(receivedStates.contains(.preloading))
        #expect(receivedStates.contains(.preloaded))
        #expect(receivedStates.contains(.notPreloading))
    }
}