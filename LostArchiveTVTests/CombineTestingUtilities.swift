import Testing
import Combine
import Foundation

/// Testing utilities for Combine publishers
/// Provides helpers for testing Combine-based code with Swift Testing framework
enum CombineTestingUtilities {
    
    /// Collects values from a publisher into an array for testing
    /// - Parameters:
    ///   - publisher: The publisher to collect values from
    ///   - count: Number of values to collect before completing
    ///   - timeout: Maximum time to wait for values
    /// - Returns: Array of collected values
    static func collect<P: Publisher>(
        from publisher: P,
        count: Int = 1,
        timeout: TimeInterval = 1.0
    ) async throws -> [P.Output] where P.Failure == Never {
        var cancellables = Set<AnyCancellable>()
        var collectedValues: [P.Output] = []
        
        return try await withCheckedThrowingContinuation { continuation in
            publisher
                .prefix(count)
                .sink { value in
                    collectedValues.append(value)
                    if collectedValues.count == count {
                        continuation.resume(returning: collectedValues)
                    }
                }
                .store(in: &cancellables)
            
            // Timeout handler
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                if collectedValues.count < count {
                    continuation.resume(throwing: CombineTestError.timeout(expected: count, received: collectedValues.count))
                }
            }
        }
    }
    
    /// Waits for a single value from a publisher
    /// - Parameters:
    ///   - publisher: The publisher to wait for
    ///   - timeout: Maximum time to wait
    /// - Returns: The first value emitted
    static func waitForValue<P: Publisher>(
        from publisher: P,
        timeout: TimeInterval = 1.0
    ) async throws -> P.Output where P.Failure == Never {
        let values = try await collect(from: publisher, count: 1, timeout: timeout)
        guard let first = values.first else {
            throw CombineTestError.noValue
        }
        return first
    }
    
    /// Creates a test publisher that emits values on demand
    /// - Parameter initialValue: The initial value to emit
    /// - Returns: A tuple containing the publisher and a send function
    static func createTestPublisher<T>(_ initialValue: T? = nil) -> (AnyPublisher<T, Never>, (T) -> Void) {
        let subject = PassthroughSubject<T, Never>()
        
        // Emit initial value if provided
        if let initialValue = initialValue {
            subject.send(initialValue)
        }
        
        return (subject.eraseToAnyPublisher(), { value in subject.send(value) })
    }
    
    /// Records all values emitted by a publisher during a test
    /// - Parameter publisher: The publisher to record
    /// - Returns: A recorder that tracks all emitted values
    static func recordValues<P: Publisher>(from publisher: P) -> ValueRecorder<P.Output> where P.Failure == Never {
        ValueRecorder(publisher: publisher)
    }
    
    /// Tests that a publisher completes within a timeout
    /// - Parameters:
    ///   - publisher: The publisher to test
    ///   - timeout: Maximum time to wait for completion
    static func expectCompletion<P: Publisher>(
        from publisher: P,
        timeout: TimeInterval = 1.0
    ) async throws where P.Failure == Never {
        var cancellables = Set<AnyCancellable>()
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var completed = false
            
            publisher
                .sink(
                    receiveCompletion: { _ in
                        completed = true
                        continuation.resume()
                    },
                    receiveValue: { _ in }
                )
                .store(in: &cancellables)
            
            // Timeout handler
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                if !completed {
                    continuation.resume(throwing: CombineTestError.notCompleted)
                }
            }
        }
    }
}

/// Records values from a publisher for testing
final class ValueRecorder<T> {
    private var cancellables = Set<AnyCancellable>()
    private(set) var values: [T] = []
    private(set) var isCompleted = false
    
    init<P: Publisher>(publisher: P) where P.Output == T, P.Failure == Never {
        publisher
            .sink(
                receiveCompletion: { [weak self] _ in
                    self?.isCompleted = true
                },
                receiveValue: { [weak self] value in
                    self?.values.append(value)
                }
            )
            .store(in: &cancellables)
    }
    
    /// Wait for a specific number of values to be recorded
    func waitForValues(count: Int, timeout: TimeInterval = 1.0) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        
        while values.count < count && Date() < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        
        if values.count < count {
            throw CombineTestError.timeout(expected: count, received: values.count)
        }
    }
}

/// Errors that can occur during Combine testing
enum CombineTestError: Error, CustomStringConvertible {
    case timeout(expected: Int, received: Int)
    case noValue
    case notCompleted
    
    var description: String {
        switch self {
        case .timeout(let expected, let received):
            return "Timeout waiting for values. Expected: \(expected), Received: \(received)"
        case .noValue:
            return "No value emitted from publisher"
        case .notCompleted:
            return "Publisher did not complete within timeout"
        }
    }
}

/// Test helpers for creating mock publishers
enum MockPublishers {
    /// Creates a publisher that emits values at regular intervals
    static func timer<T>(
        emitting value: T,
        interval: TimeInterval = 0.1,
        times: Int? = nil
    ) -> AnyPublisher<T, Never> {
        let publisher = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .map { _ in value }
        
        if let times = times {
            return publisher
                .prefix(times)
                .eraseToAnyPublisher()
        }
        
        return publisher.eraseToAnyPublisher()
    }
    
    /// Creates a publisher that emits a sequence of values
    static func sequence<T>(_ values: [T], delay: TimeInterval = 0) -> AnyPublisher<T, Never> {
        if delay > 0 {
            return values.publisher
                .flatMap { value in
                    Just(value)
                        .delay(for: .seconds(delay), scheduler: RunLoop.main)
                }
                .eraseToAnyPublisher()
        }
        
        return values.publisher.eraseToAnyPublisher()
    }
    
    /// Creates a publisher that emits after a delay
    static func delayed<T>(_ value: T, delay: TimeInterval) -> AnyPublisher<T, Never> {
        Just(value)
            .delay(for: .seconds(delay), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
    }
}

/// Extensions for testing common Combine patterns
extension Publisher where Failure == Never {
    /// Converts a publisher to an async sequence for easier testing
    func testValues(limit: Int? = nil) -> AsyncThrowingStream<Output, Error> {
        AsyncThrowingStream { continuation in
            var count = 0
            let cancellable = self.sink { value in
                continuation.yield(value)
                count += 1
                
                if let limit = limit, count >= limit {
                    continuation.finish()
                }
            }
            
            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }
}