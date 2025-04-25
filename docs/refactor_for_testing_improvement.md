# Refactoring Plan for Testing Improvements

## Problem Statement

The current testing approach has the following issues:

- Tests play actual video and audio during execution
- UI components are rendered during testing
- Real network requests are made to fetch data
- Tests are slow due to these real-world interactions
- It's difficult to test specific edge cases and error conditions

## Goals

1. Make unit tests fast and predictable
2. Focus on testing business logic in isolation
3. Eliminate UI rendering during tests
4. Eliminate actual video playback during tests
5. Eliminate real network requests during tests
6. Enable simulating edge cases and error conditions
7. Maintain high test coverage and confidence

## Overall Architectural Approach

We will implement a comprehensive dependency injection and abstraction system using these core patterns:

1. **Protocol-Based Architecture**: Define protocols for all service interfaces
2. **Dependency Injection**: Inject dependencies rather than creating them internally
3. **Wrapper/Adapter Pattern**: Create wrappers around external services like AVFoundation
4. **Repository Pattern**: Abstract data access behind repository interfaces
5. **Factory Pattern**: Create testable object instances via factories

## Components to Refactor

### 1. AVFoundation Wrapper Layer

Create wrappers and abstractions around AVFoundation components:

```
MediaPlayer (Protocol)
├── AVFoundationMediaPlayer (Production Implementation)
└── MockMediaPlayer (Test Implementation)

MediaAsset (Protocol)
├── AVFoundationMediaAsset (Production Implementation)
└── MockMediaAsset (Test Implementation)
```

**Key Interfaces**:

- `MediaPlayer`: Interface for video playback functionality
- `MediaAsset`: Interface for media asset operations
- `MediaItem`: Interface for player item operations
- `MediaTimeObserver`: Interface for observing playback time changes

### 2. Network Layer Abstraction

Create a testable network abstraction layer:

```
NetworkService (Protocol)
├── URLSessionNetworkService (Production Implementation)
└── MockNetworkService (Test Implementation)

APIClient (Protocol)
├── ArchiveOrgAPIClient (Production Implementation)
└── MockAPIClient (Test Implementation)
```

**Key Interfaces**:

- `NetworkService`: Low-level network operations
- `APIClient`: High-level API operations
- `RequestBuilder`: Construct API requests
- `ResponseParser`: Parse API responses

### 3. Database Access Layer

Abstract database operations:

```
DataRepository (Protocol)
├── SQLiteDataRepository (Production Implementation)
└── InMemoryDataRepository (Test Implementation)
```

**Key Interfaces**:

- `IdentifierRepository`: Access video identifiers
- `CollectionRepository`: Access collection information
- `SettingsRepository`: Access user preferences

### 4. Core Service Abstractions

Create interfaces for all key application services:

```
VideoService (Protocol)
├── ArchiveVideoService (Production Implementation)
└── MockVideoService (Test Implementation)

CacheService (Protocol)
├── FilesystemCacheService (Production Implementation)
└── InMemoryCacheService (Test Implementation)
```

### 5. View Model Refactoring

Refactor view models to use the abstracted services:

```
VideoPlayerViewModel
└── Dependencies:
    ├── VideoService
    ├── MediaPlayer
    ├── CacheService
    └── etc.
```

## Implementation Approach

### Dependency Injection System

1. **Constructor Injection**: Pass dependencies through initializers
2. **Environment-Based DI**: Create environment configurations for testing vs. production
3. **Factory Methods**: Create factory methods for complex object creation

### AVFoundation Wrapping Strategy

1. Identify all direct AVFoundation usages in the codebase
2. Design protocol interfaces matching required functionality
3. Create production implementations using actual AVFoundation
4. Create test implementations that simulate behavior without actual playback

For example:

```swift
protocol MediaPlayer {
    var isPlaying: Bool { get }
    var currentTime: Double { get }
    var duration: Double { get }
    var currentURL: URL? { get }
    
    func play()
    func pause()
    func seek(to time: TimeInterval)
    func replaceCurrentItem(with item: MediaItem?)
    func observeTimeChanges(interval: TimeInterval, callback: @escaping (TimeInterval) -> Void) -> Any
    func removeTimeObserver(_ observer: Any)
}
```

### Network Abstraction Strategy

1. Create a protocol-based network layer
2. Use dependency injection to provide either real or mock implementations
3. Store sample response data for testing (JSON files in test bundle)
4. Create mock implementations that return predefined responses

For example:

```swift
protocol APIClient {
    func fetchMetadata(for identifier: String) async throws -> ArchiveMetadata
    func fetchVideoURL(for file: ArchiveFile) async throws -> URL
}
```

### Testing Strategy

1. **Unit Tests**: Test business logic in isolation with mock dependencies
2. **Integration Tests**: Test integration between components with mock external dependencies
3. **UI Tests**: Maintain minimal UI tests for critical user flows

### Performance Optimization

1. Use in-memory data stores for tests
2. Use precomputed responses for network requests
3. Avoid file I/O operations during tests
4. Skip time-dependent operations in tests

## Implementation Phases

### Phase 1: Core Infrastructure

1. Create base protocols for key abstractions
2. Implement dependency injection system
3. Create test utilities and base mock implementations

### Phase 2: Media Layer Refactoring

1. Create AVFoundation wrapper protocols
2. Implement production versions using actual AVFoundation
3. Implement test versions with simulated behavior
4. Refactor VideoPlaybackManager to use the new abstractions

### Phase 3: Network Layer Refactoring

1. Create network service abstractions
2. Implement real and mock versions
3. Refactor ArchiveService to use the new network layer

### Phase 4: Data Layer Refactoring

1. Create data repository abstractions
2. Implement real and in-memory versions
3. Refactor database access code to use the repositories

### Phase 5: View Model Refactoring

1. Refactor view models to accept dependencies
2. Create factories for view model creation
3. Update tests to use mock dependencies

### Phase 6: Testing Enhancement

1. Create comprehensive test suite using mock implementations
2. Add tests for edge cases and error conditions
3. Measure and optimize test performance

## Testing Guidelines

### Writing Testable Code

1. **Dependency Injection**: Always use dependency injection
2. **Small, Focused Classes**: Keep classes small and focused on a single responsibility
3. **Pure Functions**: Prefer pure functions when possible
4. **State Management**: Make state changes explicit and testable
5. **Error Handling**: Make error paths explicit and testable

### Testing Best Practices

1. **Arrange-Act-Assert**: Structure tests with clear setup, action, and verification
2. **Test Doubles**: Use appropriate test doubles (mocks, stubs, fakes)
3. **Test Isolation**: Tests should not depend on each other
4. **Coverage**: Aim for high logical coverage, not just line coverage
5. **Readability**: Tests should serve as documentation

## Example Mock Implementations

### Media Player Mock

```swift
class MockMediaPlayer: MediaPlayer {
    var isPlaying = false
    var currentTime: Double = 0
    var duration: Double = 120.0
    var currentURL: URL? = URL(string: "https://example.com/test.mp4")
    
    // Test control properties
    var playWasCalled = false
    var pauseWasCalled = false
    var seekPositions: [Double] = []
    
    func play() {
        isPlaying = true
        playWasCalled = true
    }
    
    func pause() {
        isPlaying = false
        pauseWasCalled = true
    }
    
    func seek(to time: TimeInterval) {
        currentTime = time
        seekPositions.append(time)
    }
    
    // Implement other methods...
}
```

### Network Service Mock

```swift
class MockAPIClient: APIClient {
    var metadataToReturn: ArchiveMetadata?
    var videoURLToReturn: URL?
    var errorToThrow: Error?
    
    var fetchMetadataCallCount = 0
    var fetchVideoURLCallCount = 0
    var lastRequestedIdentifier: String?
    
    func fetchMetadata(for identifier: String) async throws -> ArchiveMetadata {
        fetchMetadataCallCount += 1
        lastRequestedIdentifier = identifier
        
        if let error = errorToThrow {
            throw error
        }
        
        return metadataToReturn ?? createDefaultMetadata(for: identifier)
    }
    
    // Implement other methods...
    
    private func createDefaultMetadata(for identifier: String) -> ArchiveMetadata {
        // Create a sample metadata object for testing
    }
}
```

## Next Steps

1. Review and approve this architectural plan
2. Create a detailed implementation timeline
3. Begin implementing phase 1 with core abstractions
4. Run tests frequently to ensure functionality is maintained
5. Gradually migrate existing tests to the new approach