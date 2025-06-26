import Testing
import Combine
import Foundation
@testable import LATV

/// Tests for VideoEditingService Combine publishers
@MainActor
@Suite(.serialized)
struct VideoEditingServiceTests {
    
    // Helper to ensure clean state for each test
    private func setupCleanState() {
        VideoEditingService.resetForTesting()
        // Small delay to ensure any pending events are cleared
        Thread.sleep(forTimeInterval: 0.05)
    }
    
    // MARK: - Start Video Trimming Publisher Tests
    
    @Test
    func startVideoTrimmingPublisher_sendsSingleEvent() async throws {
        // Arrange
        setupCleanState()
        var receivedEvent = false
        var cancellables = Set<AnyCancellable>()
        
        // Subscribe
        VideoEditingService.startVideoTrimmingPublisher
            .sink { _ in
                receivedEvent = true
            }
            .store(in: &cancellables)
        
        // Act
        await VideoEditingService.startVideoTrimming()
        
        // Wait for event
        try? await Task.sleep(for: .milliseconds(100))
        
        // Assert
        #expect(receivedEvent == true)
    }
    
    @Test
    func startVideoTrimmingPublisher_multipleSubscribersReceiveEvents() async throws {
        // Arrange
        setupCleanState()
        var subscriber1Count = 0
        var subscriber2Count = 0
        var subscriber3Count = 0
        var cancellables = Set<AnyCancellable>()
        
        // Subscribe multiple times
        VideoEditingService.startVideoTrimmingPublisher
            .sink { _ in
                subscriber1Count += 1
            }
            .store(in: &cancellables)
        
        VideoEditingService.startVideoTrimmingPublisher
            .sink { _ in
                subscriber2Count += 1
            }
            .store(in: &cancellables)
        
        VideoEditingService.startVideoTrimmingPublisher
            .sink { _ in
                subscriber3Count += 1
            }
            .store(in: &cancellables)
        
        // Act
        await VideoEditingService.startVideoTrimming()
        
        // Wait for events to propagate
        try? await Task.sleep(for: .milliseconds(100))
        
        // Assert - all subscribers should receive the event
        #expect(subscriber1Count == 1)
        #expect(subscriber2Count == 1)
        #expect(subscriber3Count == 1)
    }
    
    @Test
    func startVideoTrimmingPublisher_sendsMultipleEventsInSequence() async throws {
        // Arrange
        setupCleanState()
        var eventCount = 0
        var cancellables = Set<AnyCancellable>()
        
        VideoEditingService.startVideoTrimmingPublisher
            .sink { _ in
                eventCount += 1
            }
            .store(in: &cancellables)
        
        // Act - send multiple events
        await VideoEditingService.startVideoTrimming()
        try? await Task.sleep(for: .milliseconds(50))
        await VideoEditingService.startVideoTrimming()
        try? await Task.sleep(for: .milliseconds(50))
        await VideoEditingService.startVideoTrimming()
        
        // Wait for all events
        try? await Task.sleep(for: .milliseconds(100))
        
        // Assert
        #expect(eventCount == 3)
    }
    
    @Test
    func startVideoTrimmingPublisher_threadSafety_concurrentSends() async throws {
        // Arrange
        setupCleanState()
        var totalEventCount = 0
        var cancellables = Set<AnyCancellable>()
        let lock = NSLock()
        
        VideoEditingService.startVideoTrimmingPublisher
            .sink { _ in
                lock.lock()
                totalEventCount += 1
                lock.unlock()
            }
            .store(in: &cancellables)
        
        // Act - send multiple events concurrently
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                group.addTask { @MainActor in
                    await VideoEditingService.startVideoTrimming()
                }
            }
        }
        
        // Wait for all events
        try? await Task.sleep(for: .milliseconds(200))
        
        // Assert - all events should be received
        #expect(totalEventCount == 20)
    }
    
    @Test
    func startVideoTrimmingPublisher_mainThreadDelivery() async throws {
        // Arrange
        setupCleanState()
        var receivedOnMainThread = false
        var cancellables = Set<AnyCancellable>()
        
        await withCheckedContinuation { continuation in
            VideoEditingService.startVideoTrimmingPublisher
                .sink { _ in
                    receivedOnMainThread = Thread.isMainThread
                    continuation.resume()
                }
                .store(in: &cancellables)
            
            // Act - send from background thread
            Task.detached {
                await VideoEditingService.startVideoTrimming()
            }
        }
        
        // Assert - should be delivered on main thread
        #expect(receivedOnMainThread == true)
    }
    
    @Test
    func startVideoTrimmingPublisher_subscriptionAfterReset() async throws {
        // Arrange
        setupCleanState()
        var firstSubscriberCount = 0
        var secondSubscriberCount = 0
        var cancellables = Set<AnyCancellable>()
        
        // First subscriber
        VideoEditingService.startVideoTrimmingPublisher
            .sink { _ in
                firstSubscriberCount += 1
            }
            .store(in: &cancellables)
        
        // Send first event
        await VideoEditingService.startVideoTrimming()
        try? await Task.sleep(for: .milliseconds(50))
        
        // Reset
        VideoEditingService.resetForTesting()
        
        // Second subscriber on new publisher
        VideoEditingService.startVideoTrimmingPublisher
            .sink { _ in
                secondSubscriberCount += 1
            }
            .store(in: &cancellables)
        
        // Send second event
        await VideoEditingService.startVideoTrimming()
        try? await Task.sleep(for: .milliseconds(50))
        
        // Assert
        #expect(firstSubscriberCount == 1) // Only received event before reset
        #expect(secondSubscriberCount == 1) // Only received event after reset
    }
    
    @Test
    func startVideoTrimmingPublisher_cancellationRemovesSubscription() async throws {
        // Arrange
        setupCleanState()
        var eventCount = 0
        var cancellables = Set<AnyCancellable>()
        
        VideoEditingService.startVideoTrimmingPublisher
            .sink { _ in
                eventCount += 1
            }
            .store(in: &cancellables)
        
        // Send first event - should be received
        await VideoEditingService.startVideoTrimming()
        try? await Task.sleep(for: .milliseconds(100))
        
        // Verify first event was received
        #expect(eventCount == 1)
        
        // Cancel subscription
        cancellables.removeAll()
        
        // Wait a bit to ensure cancellation takes effect
        try? await Task.sleep(for: .milliseconds(100))
        
        // Send second event - should not be received
        await VideoEditingService.startVideoTrimming()
        try? await Task.sleep(for: .milliseconds(100))
        
        // Assert - count should still be 1
        #expect(eventCount == 1) // Only the first event should be received
    }
    
    @Test
    func startVideoTrimmingPublisher_rapidFireEvents() async throws {
        // Arrange
        setupCleanState()
        let recorder = CombineTestingUtilities.recordValues(from: VideoEditingService.startVideoTrimmingPublisher)
        
        // Act - send many events rapidly
        for _ in 0..<50 {
            await VideoEditingService.startVideoTrimming()
        }
        
        // Wait for all events
        try await recorder.waitForValues(count: 50, timeout: 2.0)
        
        // Assert - all events should be received
        #expect(recorder.values.count == 50)
    }
    
    @Test
    func startVideoTrimmingPublisher_lateSubscription() async throws {
        // Arrange
        setupCleanState()
        var receivedEvent = false
        var cancellables = Set<AnyCancellable>()
        
        // Send event before subscription
        await VideoEditingService.startVideoTrimming()
        try? await Task.sleep(for: .milliseconds(100))
        
        // Subscribe after event
        VideoEditingService.startVideoTrimmingPublisher
            .sink { _ in
                receivedEvent = true
            }
            .store(in: &cancellables)
        
        // Wait briefly
        try? await Task.sleep(for: .milliseconds(100))
        
        // Assert - should not receive past event (PassthroughSubject doesn't replay)
        #expect(receivedEvent == false)
        
        // Send new event
        await VideoEditingService.startVideoTrimming()
        try? await Task.sleep(for: .milliseconds(100))
        
        // Assert - should receive new event
        #expect(receivedEvent == true)
    }
    
    @Test
    func startVideoTrimmingPublisher_combineWithOtherPublishers() async throws {
        // Arrange
        setupCleanState()
        var combinedEventCount = 0
        var cancellables = Set<AnyCancellable>()
        
        // Create a timer publisher
        let timerPublisher = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .prefix(3)
            .map { _ in () }
        
        // Combine with video trimming publisher
        Publishers.Merge(
            VideoEditingService.startVideoTrimmingPublisher,
            timerPublisher
        )
        .sink { _ in
            combinedEventCount += 1
        }
        .store(in: &cancellables)
        
        // Act - send some trimming events
        await VideoEditingService.startVideoTrimming()
        try? await Task.sleep(for: .milliseconds(150))
        await VideoEditingService.startVideoTrimming()
        
        // Wait for timer to complete
        try? await Task.sleep(for: .milliseconds(400))
        
        // Assert - should receive both trimming events and timer events
        #expect(combinedEventCount >= 5) // 2 trimming + 3 timer events
    }
}