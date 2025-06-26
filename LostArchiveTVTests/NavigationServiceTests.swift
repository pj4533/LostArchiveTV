import Testing
import Combine
import Foundation
@testable import LATV

/// Tests for NavigationService Combine publishers
@MainActor
@Suite(.serialized)
struct NavigationServiceTests {
    
    // Helper to ensure clean state for each test
    private func setupCleanState() {
        NavigationService.resetForTesting()
        // Small delay to ensure any pending events are cleared
        Thread.sleep(forTimeInterval: 0.05)
    }
    
    // MARK: - Similar Videos Publisher Tests
    
    @Test
    func similarVideosPublisher_sendsSingleEvent() async throws {
        // Arrange
        setupCleanState()
        let testVideo = SimilarVideo(
            identifier: "test-123",
            title: "Test Video",
            description: "Test Description",
            thumbnailURL: URL(string: "https://example.com/thumb.jpg")!,
            fileCount: 1
        )
        var receivedVideo: SimilarVideo?
        var cancellables = Set<AnyCancellable>()
        
        // Subscribe
        NavigationService.similarVideosPublisher
            .sink { video in
                receivedVideo = video
            }
            .store(in: &cancellables)
        
        // Act
        await NavigationService.showSimilarVideos(for: testVideo)
        
        // Wait for event
        try? await Task.sleep(for: .milliseconds(100))
        
        // Assert
        #expect(receivedVideo != nil)
        #expect(receivedVideo?.identifier == "test-123")
        #expect(receivedVideo?.title == "Test Video")
        #expect(receivedVideo?.description == "Test Description")
    }
    
    @Test
    func similarVideosPublisher_multipleSubscribersReceiveEvents() async throws {
        // Arrange
        setupCleanState()
        var subscriber1Values: [SimilarVideo] = []
        var subscriber2Values: [SimilarVideo] = []
        var cancellables = Set<AnyCancellable>()
        
        let testVideo = SimilarVideo(
            identifier: "multi-sub-123",
            title: "Multi Sub Test",
            description: "Testing multiple subscribers",
            thumbnailURL: URL(string: "https://example.com/thumb.jpg")!,
            fileCount: 2
        )
        
        // Subscribe multiple times
        NavigationService.similarVideosPublisher
            .sink { video in
                subscriber1Values.append(video)
            }
            .store(in: &cancellables)
        
        NavigationService.similarVideosPublisher
            .sink { video in
                subscriber2Values.append(video)
            }
            .store(in: &cancellables)
        
        // Act
        await NavigationService.showSimilarVideos(for: testVideo)
        
        // Wait for events to propagate
        try? await Task.sleep(for: .milliseconds(100))
        
        // Assert - both subscribers should receive the event
        #expect(subscriber1Values.count == 1)
        #expect(subscriber2Values.count == 1)
        #expect(subscriber1Values[0].identifier == "multi-sub-123")
        #expect(subscriber2Values[0].identifier == "multi-sub-123")
    }
    
    @Test
    func similarVideosPublisher_sendsMultipleEventsInSequence() async throws {
        // Arrange
        setupCleanState()
        let video1 = SimilarVideo(
            identifier: "seq-1",
            title: "Video 1",
            description: "First video",
            thumbnailURL: URL(string: "https://example.com/1.jpg")!,
            fileCount: 1
        )
        let video2 = SimilarVideo(
            identifier: "seq-2",
            title: "Video 2",
            description: "Second video",
            thumbnailURL: URL(string: "https://example.com/2.jpg")!,
            fileCount: 2
        )
        let video3 = SimilarVideo(
            identifier: "seq-3",
            title: "Video 3",
            description: "Third video",
            thumbnailURL: URL(string: "https://example.com/3.jpg")!,
            fileCount: 3
        )
        var receivedVideos: [SimilarVideo] = []
        var cancellables = Set<AnyCancellable>()
        
        // Subscribe
        NavigationService.similarVideosPublisher
            .sink { video in
                receivedVideos.append(video)
            }
            .store(in: &cancellables)
        
        // Act
        await NavigationService.showSimilarVideos(for: video1)
        await NavigationService.showSimilarVideos(for: video2)
        await NavigationService.showSimilarVideos(for: video3)
        
        // Wait for events
        try? await Task.sleep(for: .milliseconds(100))
        
        // Assert
        #expect(receivedVideos.count == 3)
        #expect(receivedVideos[0].identifier == "seq-1")
        #expect(receivedVideos[1].identifier == "seq-2")
        #expect(receivedVideos[2].identifier == "seq-3")
    }
    
    @Test
    func similarVideosPublisher_threadSafety_concurrentSends() async throws {
        // Arrange
        setupCleanState()
        let recorder = CombineTestingUtilities.recordValues(from: NavigationService.similarVideosPublisher)
        
        // Act - send multiple events concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask { @MainActor in
                    let video = SimilarVideo(
                        identifier: "concurrent-\(i)",
                        title: "Concurrent Video \(i)",
                        description: "Concurrent test \(i)",
                        thumbnailURL: URL(string: "https://example.com/\(i).jpg")!,
                        fileCount: i
                    )
                    await NavigationService.showSimilarVideos(for: video)
                }
            }
        }
        
        // Wait for all events
        try await recorder.waitForValues(count: 10)
        
        // Assert - all events should be received
        #expect(recorder.values.count == 10)
        
        // Verify all identifiers are present (order may vary)
        let identifiers = Set(recorder.values.map { $0.identifier })
        let expectedIdentifiers = Set((0..<10).map { "concurrent-\($0)" })
        #expect(identifiers == expectedIdentifiers)
    }
    
    @Test
    func similarVideosPublisher_mainThreadDelivery() async throws {
        // Arrange
        setupCleanState()
        var receivedOnMainThread = false
        var cancellables = Set<AnyCancellable>()
        
        await withCheckedContinuation { continuation in
            NavigationService.similarVideosPublisher
                .sink { _ in
                    receivedOnMainThread = Thread.isMainThread
                    continuation.resume()
                }
                .store(in: &cancellables)
            
            // Act - send from background thread
            Task.detached {
                let video = SimilarVideo(
                    identifier: "thread-test",
                    title: "Thread Test",
                    description: "Testing thread delivery",
                    thumbnailURL: URL(string: "https://example.com/thread.jpg")!,
                    fileCount: 1
                )
                await NavigationService.showSimilarVideos(for: video)
            }
        }
        
        // Assert - should be delivered on main thread
        #expect(receivedOnMainThread == true)
    }
    
    @Test
    func similarVideosPublisher_subscriptionAfterReset() async throws {
        // Arrange
        setupCleanState()
        var firstSubscriberValues: [SimilarVideo] = []
        var secondSubscriberValues: [SimilarVideo] = []
        var cancellables = Set<AnyCancellable>()
        
        let video1 = SimilarVideo(
            identifier: "before-reset",
            title: "Before Reset",
            description: "Sent before reset",
            thumbnailURL: URL(string: "https://example.com/before.jpg")!,
            fileCount: 1
        )
        let video2 = SimilarVideo(
            identifier: "after-reset",
            title: "After Reset",
            description: "Sent after reset",
            thumbnailURL: URL(string: "https://example.com/after.jpg")!,
            fileCount: 2
        )
        
        // First subscriber
        NavigationService.similarVideosPublisher
            .sink { video in
                firstSubscriberValues.append(video)
            }
            .store(in: &cancellables)
        
        // Send first event
        await NavigationService.showSimilarVideos(for: video1)
        try? await Task.sleep(for: .milliseconds(50))
        
        // Reset
        NavigationService.resetForTesting()
        
        // Second subscriber on new publisher
        NavigationService.similarVideosPublisher
            .sink { video in
                secondSubscriberValues.append(video)
            }
            .store(in: &cancellables)
        
        // Send second event
        await NavigationService.showSimilarVideos(for: video2)
        try? await Task.sleep(for: .milliseconds(50))
        
        // Assert
        #expect(firstSubscriberValues.count == 1)
        #expect(firstSubscriberValues[0].identifier == "before-reset")
        #expect(secondSubscriberValues.count == 1)
        #expect(secondSubscriberValues[0].identifier == "after-reset")
    }
    
    @Test
    func similarVideosPublisher_multipleSubscriptionsCleanup() async throws {
        // Arrange
        setupCleanState()
        var subscription1Count = 0
        var subscription2Count = 0
        
        // Act - create and cancel subscriptions
        do {
            var cancellables = Set<AnyCancellable>()
            
            NavigationService.similarVideosPublisher
                .sink { _ in
                    subscription1Count += 1
                }
                .store(in: &cancellables)
            
            NavigationService.similarVideosPublisher
                .sink { _ in
                    subscription2Count += 1
                }
                .store(in: &cancellables)
            
            // Send event while subscribed
            let video = SimilarVideo(
                identifier: "sub-test",
                title: "Subscription Test",
                description: "Testing subscription cleanup",
                thumbnailURL: URL(string: "https://example.com/sub.jpg")!,
                fileCount: 1
            )
            await NavigationService.showSimilarVideos(for: video)
            try? await Task.sleep(for: .milliseconds(50))
            
            // Subscriptions should receive the event
            #expect(subscription1Count == 1)
            #expect(subscription2Count == 1)
            
            // Cancellables go out of scope here, canceling subscriptions
        }
        
        // Send another event after subscriptions are canceled
        let video2 = SimilarVideo(
            identifier: "sub-test-2",
            title: "After Cleanup",
            description: "Should not be received",
            thumbnailURL: URL(string: "https://example.com/sub2.jpg")!,
            fileCount: 1
        )
        await NavigationService.showSimilarVideos(for: video2)
        try? await Task.sleep(for: .milliseconds(50))
        
        // Assert - counts should not increase
        #expect(subscription1Count == 1)
        #expect(subscription2Count == 1)
    }
}