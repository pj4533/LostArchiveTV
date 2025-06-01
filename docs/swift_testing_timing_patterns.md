# Swift Testing Timing Patterns

This document provides patterns and solutions for handling timing issues in Swift Testing framework, particularly when testing asynchronous code, Combine publishers, and notifications.

## Key Challenges

1. **Swift Testing's confirmation API** doesn't wait for asynchronous events like XCTest's expectations
2. **Combine publishers** and **NotificationCenter** events often have timing dependencies  
3. **Race conditions** occur when tests check state before async operations complete
4. **Thread safety** issues when mixing MainActor code with background operations

## Solution: withCheckedContinuation Pattern

The primary solution is using Swift's `withCheckedContinuation` to bridge async/await with callback-based APIs like Combine publishers.

### Basic Pattern

```swift
@Test
func testAsyncPublisher() async {
    var receivedValue = false
    var cancellables = Set<AnyCancellable>()
    
    await withCheckedContinuation { continuation in
        // Subscribe to publisher
        somePublisher
            .sink { value in
                receivedValue = true
                continuation.resume()
            }
            .store(in: &cancellables)
        
        // Trigger the action
        Task {
            await triggerAsyncAction()
        }
        
        // Add timeout to prevent hanging
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            continuation.resume() // Resume anyway after timeout
        }
    }
    
    #expect(receivedValue == true)
}
```

### Key Points

1. **Set up subscriptions first** before triggering actions
2. **Always include a timeout** to prevent tests from hanging
3. **Use Task blocks** for async operations within the continuation
4. **Resume exactly once** - either on success or timeout

## Common Patterns

### 1. Testing Combine Publishers

```swift
@Test
func testPublisherEmitsValue() async {
    var receivedStatus: Status?
    var cancellables = Set<AnyCancellable>()
    
    await withCheckedContinuation { continuation in
        MyService.statusPublisher
            .sink { status in
                receivedStatus = status
                continuation.resume()
            }
            .store(in: &cancellables)
        
        Task {
            await myService.triggerStatusChange()
        }
        
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            continuation.resume()
        }
    }
    
    #expect(receivedStatus == .expected)
}
```

### 2. Testing Multiple Events

```swift
@Test
func testMultipleNotifications() async {
    var eventCount = 0
    let expectedCount = 3
    var cancellables = Set<AnyCancellable>()
    
    await withCheckedContinuation { continuation in
        publisher
            .sink { _ in
                eventCount += 1
                if eventCount >= expectedCount {
                    continuation.resume()
                }
            }
            .store(in: &cancellables)
        
        Task {
            await triggerMultipleEvents()
        }
        
        Task {
            try? await Task.sleep(for: .seconds(1))
            continuation.resume()
        }
    }
    
    #expect(eventCount >= expectedCount)
}
```

### 3. Testing State Changes

```swift
@Test
func testStateTransition() async {
    let manager = StateManager()
    var stateChanged = false
    var cancellables = Set<AnyCancellable>()
    
    await withCheckedContinuation { continuation in
        manager.$state
            .dropFirst() // Skip initial value
            .sink { newState in
                if newState == .expected {
                    stateChanged = true
                    continuation.resume()
                }
            }
            .store(in: &cancellables)
        
        Task {
            // Small delay to ensure subscription is ready
            try? await Task.sleep(for: .milliseconds(50))
            manager.triggerStateChange()
        }
        
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            continuation.resume()
        }
    }
    
    #expect(stateChanged == true)
}
```

## Best Practices

1. **Avoid `.receive(on:)` when the publisher already dispatches to main**
   - Can cause deadlocks or timing issues
   
2. **Use appropriate timeouts**
   - Short for unit tests (100-500ms)
   - Longer for integration tests (1-2 seconds)
   
3. **Clean state between tests**
   ```swift
   private func setupCleanState() async {
       Service.resetForTesting()
       try? await Task.sleep(for: .milliseconds(50))
   }
   ```

4. **Consider test-specific extensions**
   ```swift
   extension MyService {
       static func resetForTesting() {
           publisher = PassthroughSubject<Status, Never>()
       }
   }
   ```

## Debugging Tips

1. **Add logging** to understand timing:
   ```swift
   print("Setting up subscription at \(Date())")
   print("Received event at \(Date())")
   ```

2. **Check thread execution**:
   ```swift
   #expect(Thread.isMainThread == true)
   ```

3. **Verify subscription setup**:
   ```swift
   var subscriptionEstablished = false
   publisher
       .handleEvents(receiveSubscription: { _ in
           subscriptionEstablished = true
       })
       .sink { ... }
   ```

## Migration from XCTest

When migrating from XCTest expectations:

**XCTest Pattern:**
```swift
let expectation = expectation(description: "Publisher emits")
publisher.sink { _ in
    expectation.fulfill()
}.store(in: &cancellables)
wait(for: [expectation], timeout: 1.0)
```

**Swift Testing Pattern:**
```swift
await withCheckedContinuation { continuation in
    publisher.sink { _ in
        continuation.resume()
    }.store(in: &cancellables)
    
    Task {
        try? await Task.sleep(for: .seconds(1))
        continuation.resume()
    }
}
```

## References

- [Swift Testing Documentation](https://developer.apple.com/documentation/testing/)
- [Swift Concurrency: Continuations](https://www.swift.org/documentation/concurrency/)
- [Testing Combine Publishers with Swift Testing](https://lumley.io/blogs/swift-testing-with-combine/)