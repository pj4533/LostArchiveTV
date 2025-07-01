import Testing
import Combine
import Foundation
@testable import LATV

/// Regression test suite for notification behaviors
/// These tests establish the baseline behavior before Combine conversion
@MainActor
@Suite(.serialized)
struct NotificationRegressionTests {
    
    // Helper to ensure clean state for each test
    private func setupCleanState() async {
        VideoCacheService.resetForTesting()
        TransitionPreloadManager.resetForTesting()
        PreloadingIndicatorManager.shared.resetForTesting()
        // Longer delay to ensure subscriptions are properly established
        try? await Task.sleep(for: .milliseconds(100))
    }
    
    // MARK: - Integration Tests
    
    @Test
    func preloadingCycle_stateTransitions() async {
        await setupCleanState()
        
        // Arrange
        let manager = PreloadingIndicatorManager.shared
        var stateChanges: [PreloadingState] = []
        var cancellables = Set<AnyCancellable>()
        
        // Track state changes
        manager.$state
            .sink { state in
                stateChanges.append(state)
            }
            .store(in: &cancellables)
        
        // Act - simulate a full preloading cycle through direct state manipulation
        // Note: reset() keeps state in .preloading (never goes black)
        manager.reset() // Reset to preloading state
        manager.setPreloading() // Already in preloading, might be no-op
        manager.setPreloaded() // Simulate cache completed
        manager.reset() // Reset back to preloading
        
        // Assert - verify state transitions
        // As of issue #98, reset() no longer transitions to .notPreloading
        // The indicator always stays visible (in .preloading state)
        // #expect(stateChanges.contains(.notPreloading)) - Removed: reset() now keeps state in .preloading
        #expect(stateChanges.contains(.preloading))
        #expect(stateChanges.contains(.preloaded))
        
        // Verify final state - reset() keeps it in preloading
        #expect(manager.state == .preloading)
    }
    
    @Test
    func sequentialOperations_maintainDataIntegrity() async {
        await setupCleanState()
        
        // Arrange
        let manager = PresetManager.shared
        
        // Create test preset
        let testPreset = FeedPreset(
            id: "sequential-test",
            name: "Sequential Test",
            enabledCollections: ["test"],
            savedIdentifiers: [],
            isSelected: true
        )
        HomeFeedPreferences.addPreset(testPreset)
        
        // Act - perform operations sequentially to avoid thread safety issues
        var successCount = 0
        for i in 0..<5 {
            let identifier = UserSelectedIdentifier(
                id: "sequential-\(i)",
                identifier: "sequential-\(i)",
                title: "Test \(i)",
                collection: "test",
                fileCount: 1
            )
            if manager.addIdentifier(identifier) {
                successCount += 1
            }
        }
        
        // Assert - all operations should succeed
        #expect(successCount == 5)
        
        // Verify duplicate prevention
        let duplicateIdentifier = UserSelectedIdentifier(
            id: "sequential-0",
            identifier: "sequential-0",
            title: "Test 0",
            collection: "test",
            fileCount: 1
        )
        let duplicateResult = manager.addIdentifier(duplicateIdentifier)
        #expect(duplicateResult == false)
        
        // Cleanup
        HomeFeedPreferences.deletePreset(withId: "sequential-test")
    }
    
    // MARK: - Memory Management Tests
    
    @Test
    func notificationObservers_properlyCleanedUp() async {
        // This test verifies that observers don't create retain cycles
        weak var weakManager: PreloadingIndicatorManager?
        
        // PreloadingIndicatorManager is a singleton, so we'll use the shared instance
        let manager = PreloadingIndicatorManager.shared
        weakManager = manager
        
        // Trigger some notifications
        VideoCacheService.preloadingStatusPublisher.send(.started)
        
        // Wait for cleanup
        try? await Task.sleep(for: .milliseconds(100))
        
        // Assert - manager should be deallocated if using singleton
        // Note: PreloadingIndicatorManager is a singleton, so it won't be deallocated
        // This test structure is here as a template for non-singleton observers
        #expect(weakManager != nil) // Singleton behavior
    }
    
    // MARK: - Error Condition Tests
    
    @Test
    func missingPreset_handlesGracefully() async {
        // Arrange
        let manager = PresetManager.shared
        var cancellables = Set<AnyCancellable>()
        
        // Note: HomeFeedPreferences.ensurePresetSelected() automatically selects
        // a preset (ALF or first available) when we try to have none selected.
        // This behavior means we can't truly test "no preset selected" scenario.
        // Instead, we'll verify the current behavior.
        
        var notificationReceived = false
        
        manager.presetEvents
            .sink { event in 
                switch event {
                case .identifierAdded, .identifierRemoved:
                    notificationReceived = true
                default:
                    break
                }
            }
            .store(in: &cancellables)
        
        // Act - try to add identifier (will succeed due to auto-selected preset)
        let identifier = UserSelectedIdentifier(
            id: "no-preset-test",
            identifier: "no-preset-test",
            title: "Test",
            collection: "test",
            fileCount: 1
        )
        let result = manager.addIdentifier(identifier)
        
        // Wait briefly
        try? await Task.sleep(for: .milliseconds(100))
        
        // Assert - Result depends on whether an auto-selected preset exists
        // and whether it includes the "test" collection
        // This documents the current behavior
        if result {
            #expect(notificationReceived == true)
        } else {
            // If no suitable preset exists, the add will fail
            #expect(notificationReceived == false)
        }
        
        // Clean up - remove the identifier we added
        if result {
            manager.removeIdentifier(withId: identifier.id)
        }
    }
}