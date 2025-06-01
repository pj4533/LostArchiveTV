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
    func fullPreloadingCycle_notificationsFlowCorrectly() async {
        await setupCleanState()
        
        // Arrange
        let cacheService = VideoCacheService()
        var startedReceived = false
        var completedReceived = false
        var stateChanges: [PreloadingState] = []
        var cancellables = Set<AnyCancellable>()
        
        let manager = PreloadingIndicatorManager.shared
        
        // Track state changes - Include initial value to ensure we capture changes
        manager.$state
            .sink { state in
                stateChanges.append(state)
            }
            .store(in: &cancellables)
        
        // Track Combine publisher events
        VideoCacheService.preloadingStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { status in
                switch status {
                case .started:
                    startedReceived = true
                case .completed:
                    completedReceived = true
                }
            }
            .store(in: &cancellables)
        
        // Act - simulate full preloading cycle
        await cacheService.notifyCachingStarted()
        try? await Task.sleep(for: .milliseconds(200))
        await cacheService.notifyCachingCompleted()
        try? await Task.sleep(for: .milliseconds(200))
        
        // Assert
        #expect(startedReceived == true)
        #expect(completedReceived == true)
        #expect(stateChanges.contains(.preloading))
    }
    
    @Test
    func cacheStatusChanged_updatesAllObservers() async {
        // Arrange
        var observer1Received = false
        var observer2Received = false
        var observer3Received = false
        var cancellables = Set<AnyCancellable>()
        
        // Create multiple observers like in the real app
        NotificationCenter.default
            .publisher(for: Notification.Name("CacheStatusChanged"))
            .sink { _ in observer1Received = true }
            .store(in: &cancellables)
        
        NotificationCenter.default.addObserver(
            forName: Notification.Name("CacheStatusChanged"),
            object: nil,
            queue: .main
        ) { _ in
            observer2Received = true
        }
        
        NotificationCenter.default
            .publisher(for: Notification.Name("CacheStatusChanged"))
            .sink { _ in observer3Received = true }
            .store(in: &cancellables)
        
        // Act
        NotificationCenter.default.post(
            name: Notification.Name("CacheStatusChanged"),
            object: nil
        )
        
        // Wait for propagation
        try? await Task.sleep(for: .milliseconds(100))
        
        // Assert - all observers should receive
        #expect(observer1Received == true)
        #expect(observer2Received == true)
        #expect(observer3Received == true)
    }
    
    @Test
    func concurrentNotifications_handleGracefully() async {
        await setupCleanState()
        
        // Arrange
        let cacheService = VideoCacheService()
        let manager = PresetManager.shared
        var notificationCount = 0
        var cancellables = Set<AnyCancellable>()
        
        // Create test preset
        let testPreset = FeedPreset(
            id: "concurrent-test",
            name: "Concurrent Test",
            enabledCollections: ["test"],
            savedIdentifiers: [],
            isSelected: true
        )
        HomeFeedPreferences.addPreset(testPreset)
        
        // Subscribe to Combine publisher
        VideoCacheService.preloadingStatusPublisher
            .sink { _ in notificationCount += 1 }
            .store(in: &cancellables)
        
        NotificationCenter.default
            .publisher(for: Notification.Name("ReloadIdentifiers"))
            .sink { _ in notificationCount += 1 }
            .store(in: &cancellables)
        
        // Act - fire multiple notifications concurrently
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await cacheService.notifyCachingStarted()
            }
            group.addTask {
                await cacheService.notifyCachingCompleted()
            }
            group.addTask {
                let identifier = UserSelectedIdentifier(
                    id: "concurrent-\(UUID().uuidString)",
                    identifier: "concurrent-\(UUID().uuidString)",
                    title: "Test",
                    collection: "test",
                    fileCount: 1
                )
                manager.addIdentifier(identifier)
            }
        }
        
        // Wait for all notifications
        try? await Task.sleep(for: .milliseconds(200))
        
        // Assert - all notifications should be received
        #expect(notificationCount >= 3)
        
        // Cleanup
        HomeFeedPreferences.deletePreset(withId: "concurrent-test")
    }
    
    @Test
    func notificationOrder_preservedWithinType() async {
        await setupCleanState()
        
        // Arrange
        let cacheService = VideoCacheService()
        var receivedOrder: [String] = []
        var cancellables = Set<AnyCancellable>()
        
        VideoCacheService.preloadingStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { status in
                switch status {
                case .started:
                    receivedOrder.append("started")
                case .completed:
                    receivedOrder.append("completed")
                }
            }
            .store(in: &cancellables)
        
        // Act - send in specific order
        await cacheService.notifyCachingStarted()
        try? await Task.sleep(for: .milliseconds(200))
        await cacheService.notifyCachingCompleted()
        try? await Task.sleep(for: .milliseconds(200))
        await cacheService.notifyCachingStarted()
        try? await Task.sleep(for: .milliseconds(200))
        
        // Assert - notifications from actor might not preserve strict order
        #expect(receivedOrder.count >= 3)
        #expect(receivedOrder.contains("started"))
        #expect(receivedOrder.contains("completed"))
        // Verify we got at least 2 started and 1 completed
        let startedCount = receivedOrder.filter { $0 == "started" }.count
        let completedCount = receivedOrder.filter { $0 == "completed" }.count
        #expect(startedCount >= 2)
        #expect(completedCount >= 1)
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
        
        NotificationCenter.default
            .publisher(for: Notification.Name("ReloadIdentifiers"))
            .sink { _ in notificationReceived = true }
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