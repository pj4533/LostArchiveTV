# Testing Async and Notification Patterns in Swift

This document provides comprehensive guidance on testing asynchronous code, notifications, and Combine publishers in Swift, with a focus on best practices and architectural considerations.

## Core Testing Philosophy

### Test Behavior, Not Implementation

The fundamental principle is to **test what your code does (behavior), not how it does it (implementation)**. This means:

- ❌ **Avoid**: Testing that a notification was posted
- ✅ **Prefer**: Testing that the state changed as a result

Example:
```swift
// ❌ Testing implementation details
#expect(notificationReceived == true)

// ✅ Testing observable behavior
#expect(manager.isPreloading == true)
#expect(viewModel.videos.count == 3)
```

## The Test Pyramid

Structure your tests according to the test pyramid:

1. **Unit Tests (70%)**: Fast, isolated tests of business logic
2. **Integration Tests (20%)**: Test component interactions
3. **End-to-End Tests (10%)**: Test complete user flows

Many timing issues arise from writing integration tests disguised as unit tests.

## Testing Strategies for Async Code

### 1. Protocol-Based Dependency Injection

Wrap dependencies in protocols to enable testing:

```swift
protocol CacheStatusNotifier {
    func notifyCachingStarted() async
    func notifyCachingCompleted() async
}

// Production implementation
class NotificationCenterNotifier: CacheStatusNotifier {
    func notifyCachingStarted() async {
        NotificationCenter.default.post(name: .cachingStarted, object: nil)
    }
}

// Test implementation
class TestNotifier: CacheStatusNotifier {
    var startedCalled = false
    var completedCalled = false
    
    func notifyCachingStarted() async {
        startedCalled = true
    }
}
```

### 2. Direct State Observation

Instead of testing notification flow:
```
Service → Notification → Manager → State Change
```

Test the final state directly:
```swift
@Test
func cachingUpdatesPreloadingState() async {
    let viewModel = VideoViewModel()
    
    await viewModel.startCaching()
    
    #expect(viewModel.preloadingState == .preloading)
}
```

### 3. Observable State Testing

For Combine publishers and @Published properties:

```swift
@Test
func statePublishesChanges() async {
    let manager = StateManager()
    var states: [State] = []
    var cancellables = Set<AnyCancellable>()
    
    // Collect all state changes
    manager.$state
        .sink { states.append($0) }
        .store(in: &cancellables)
    
    // Trigger state changes
    await manager.performAction()
    
    // Verify final state
    #expect(states.last == .completed)
    #expect(states.contains(.loading))
}
```

## Architectural Alternatives

### 1. Unidirectional Data Flow (TCA/ReSwift)

**Pros:**
- Highly testable
- Deterministic state changes
- No timing issues

**Cons:**
- Steep learning curve
- Significant refactoring

**Testing Pattern:**
```swift
@Test
func reducerHandlesAction() {
    var state = AppState()
    let action = AppAction.startLoading
    
    state = appReducer(state, action)
    
    #expect(state.isLoading == true)
}
```

### 2. State Machine Pattern

Replace complex notification flows with explicit state machines:

```swift
enum PreloadingState {
    case idle
    case loading
    case loaded(videos: [Video])
    case error(Error)
    
    mutating func handle(_ event: PreloadingEvent) {
        switch (self, event) {
        case (.idle, .startLoading):
            self = .loading
        case (.loading, .loaded(let videos)):
            self = .loaded(videos: videos)
        default:
            break
        }
    }
}
```

### 3. Async/Await Native Patterns

Leverage Swift's async/await for cleaner async testing:

```swift
@Test
func videoLoadsSuccessfully() async throws {
    let service = VideoService()
    
    let videos = try await service.loadVideos()
    
    #expect(videos.count > 0)
}
```

## Handling Combine Publishers in Tests

### Using withCheckedContinuation

For testing Combine publishers that don't naturally fit async/await:

```swift
@Test
func publisherEmitsExpectedValue() async {
    var receivedValue: String?
    var cancellables = Set<AnyCancellable>()
    
    await withCheckedContinuation { continuation in
        publisher
            .first()
            .sink { value in
                receivedValue = value
                continuation.resume()
            }
            .store(in: &cancellables)
    }
    
    #expect(receivedValue == "expected")
}
```

### Testing @Published Properties

```swift
@Test
func publishedPropertyUpdates() async {
    let viewModel = ViewModel()
    
    // Capture initial state
    let initialCount = viewModel.itemCount
    
    // Trigger change
    await viewModel.addItem()
    
    // Verify change (synchronous for @Published)
    #expect(viewModel.itemCount == initialCount + 1)
}
```

## Pragmatic Testing Approach

### What to Test

1. **Public API behavior**: What consumers of your code see
2. **State transitions**: Final states after operations
3. **Error handling**: Recovery and error states
4. **Business logic**: Calculations, transformations, validations

### What NOT to Test

1. **Implementation details**: How notifications are sent
2. **Framework behavior**: That NotificationCenter works
3. **Timing specifics**: Exact milliseconds of delays
4. **Internal state**: Private properties and methods

## Migration Strategy

When refactoring tests during Combine migration:

1. **Phase 1**: Delete tests that verify notification posting/receiving
2. **Phase 2**: Add tests that verify end state/behavior
3. **Phase 3**: Introduce protocols for better testability
4. **Phase 4**: Consider architectural improvements (TCA, etc.)

## Best Practices

1. **Avoid arbitrary delays**: Don't use `Task.sleep` to "fix" tests
2. **Make tests deterministic**: Same input should always produce same output
3. **Test one thing**: Each test should verify a single behavior
4. **Use descriptive names**: Test names should explain what they verify
5. **Keep tests fast**: Mock external dependencies
6. **Test edge cases**: Don't just test the happy path

## Example: Refactoring a Notification Test

### Before (Testing Implementation):
```swift
@Test
func notificationIsPosted() async {
    var notificationReceived = false
    let observer = NotificationCenter.default.addObserver(
        forName: .dataLoaded,
        object: nil,
        queue: .main
    ) { _ in
        notificationReceived = true
    }
    
    await service.loadData()
    try? await Task.sleep(for: .milliseconds(100))
    
    #expect(notificationReceived == true)
}
```

### After (Testing Behavior):
```swift
@Test
func dataIsLoadedSuccessfully() async {
    let viewModel = ViewModel()
    
    await viewModel.loadData()
    
    #expect(viewModel.isDataLoaded == true)
    #expect(viewModel.items.count > 0)
}
```

## Conclusion

Good tests focus on observable behavior rather than implementation details. During the Combine migration, prioritize tests that verify business logic and user-visible outcomes over tests that check internal notification mechanisms. This approach leads to more maintainable, reliable tests that won't break when implementation details change.