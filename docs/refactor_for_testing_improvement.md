# Refactoring Plan for Testing Improvements

## Problem Statement

The current testing approach has the following issues:

- Tests play actual video and audio during execution
- UI components are rendered during testing
- Real network requests are made to fetch data
- Tests are slow due to these real-world interactions
- It's difficult to test specific edge cases and error conditions
- Swift actors and concurrency add complexity to the testing approach

## Goals

1. Make unit tests fast and predictable
2. Focus on testing business logic in isolation
3. Eliminate UI rendering during tests
4. Eliminate actual video playback during tests
5. Eliminate real network requests during tests
6. Enable simulating edge cases and error conditions
7. Maintain high test coverage and confidence
8. Handle Swift actor isolation correctly in abstractions
9. Avoid using Actor keyword - instead use async/await if possible

## Lessons Learned from Initial Attempt

### Actor Isolation Issues

- **Actor Protocol Methods**: Methods in protocols need to be marked as `async` if they will be implemented by actor types to maintain isolation.
- **Self References in Closures**: Self references in closures within actors require explicit `self` to prevent memory leaks and clarify execution context.
- **Suspension Points**: Avoid suspension points in actor property accessors by moving complex operations to methods.
- **Protocol Inheritance**: When an actor conforms to a protocol, all isolated methods need to be marked `async` in the protocol definition.

### UI and AVFoundation Abstraction Issues

- **Avoid Exposing AVFoundation Types**: Don't expose concrete AVFoundation types like `AVPlayer` or `CMTime` in protocol interfaces as this leaks implementation details.
- **UI Adapter Pattern**: Implement an adapter layer that bridges between UI-specific requirements (like AVPlayerLayer) and pure abstracted interfaces.
- **Value Types for Boundaries**: Use simple value types (like `Double` for time) at abstraction boundaries rather than complex types like `CMTime`.
- **Separation of Concerns**: Ensure each protocol focuses on a single responsibility to make mocking easier in tests.

### Dependency Injection Challenges

- **Unified Factory**: Create a unified service factory to simplify dependency injection across the application.
- **Default Dependencies**: Provide sensible defaults in initializers while allowing injection for testing.
- **Shared Dependencies**: Be careful with dependencies that need to be shared across multiple components.

## Overall Architectural Approach

We will implement a comprehensive dependency injection and abstraction system using these core patterns:

1. **Protocol-Based Architecture**: Define protocols for all service interfaces
2. **Dependency Injection**: Inject dependencies rather than creating them internally
3. **Wrapper/Adapter Pattern**: Create wrappers around external services like AVFoundation
4. **Repository Pattern**: Abstract data access behind repository interfaces
5. **Factory Pattern**: Create testable object instances via factories
6. **Adapter Pattern**: Bridge between UI-specific requirements and testable abstractions

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
// Refined protocol that avoids exposing AVFoundation types and handles actor isolation
protocol MediaPlayer {
    var isPlaying: Bool { get async }
    var currentTime: Double { get async }
    var duration: Double { get async }
    var currentURL: URL? { get async }
    var rate: Float { get async set }
    var isMuted: Bool { get async set }
    
    func play() async
    func pause() async
    func seek(to time: Double) async
    func replaceCurrentItem(with url: URL?) async
    func addPeriodicTimeObserver(forInterval interval: Double, queue: DispatchQueue?, using block: @escaping (Double) -> Void) async -> UUID
    func removeTimeObserver(id: UUID) async
    
    // Adapter methods for UI integration (kept separate from core logic)
    func getPlayerForDisplay() -> Any?
}

// Example implementation adapter for UI integration
class MediaPlayerViewAdapter {
    private let player: MediaPlayer
    
    init(player: MediaPlayer) {
        self.player = player
    }
    
    // Returns AVPlayerLayer for SwiftUI integration
    func createPlayerLayer() -> CALayer {
        if let avPlayer = player.getPlayerForDisplay() as? AVPlayer {
            let playerLayer = AVPlayerLayer(player: avPlayer)
            playerLayer.videoGravity = .resizeAspectFill
            return playerLayer
        }
        // Return empty layer for mock implementation
        return CALayer()
    }
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
// Updated mock implementation with actor isolation and test instrumentation
actor MockMediaPlayer: MediaPlayer {
    // State properties
    private(set) var isPlayingValue = false
    private(set) var currentTimeValue: Double = 0
    private(set) var durationValue: Double = 120.0
    private(set) var currentURLValue: URL? = URL(string: "https://example.com/test.mp4")
    private(set) var rateValue: Float = 1.0
    private(set) var isMutedValue: Bool = false
    
    // Test instrumentation properties
    private(set) var playCallCount = 0
    private(set) var pauseCallCount = 0
    private(set) var seekPositions: [Double] = []
    private(set) var timeObservers: [UUID: (Double) -> Void] = [:]
    private var nextObserverID = UUID()
    
    // Access to state with actor isolation
    var isPlaying: Bool { isPlayingValue }
    var currentTime: Double { currentTimeValue }
    var duration: Double { durationValue }
    var currentURL: URL? { currentURLValue }
    
    var rate: Float {
        get { rateValue }
        set { rateValue = newValue }
    }
    
    var isMuted: Bool {
        get { isMutedValue }
        set { isMutedValue = newValue }
    }
    
    // Test behavior simulation
    func play() async {
        isPlayingValue = true
        playCallCount += 1
    }
    
    func pause() async {
        isPlayingValue = false
        pauseCallCount += 1
    }
    
    func seek(to time: Double) async {
        currentTimeValue = time
        seekPositions.append(time)
    }
    
    func replaceCurrentItem(with url: URL?) async {
        currentURLValue = url
        currentTimeValue = 0
    }
    
    func addPeriodicTimeObserver(forInterval interval: Double, queue: DispatchQueue?, using block: @escaping (Double) -> Void) async -> UUID {
        let id = nextObserverID
        nextObserverID = UUID()
        timeObservers[id] = block
        return id
    }
    
    func removeTimeObserver(id: UUID) async {
        timeObservers.removeValue(forKey: id)
    }
    
    // UI adapter methods
    func getPlayerForDisplay() -> Any? {
        return nil // Mock implementation doesn't need a real player
    }
    
    // Test helper methods
    func simulateTimeUpdate(to newTime: Double) async {
        currentTimeValue = newTime
        for (_, callback) in timeObservers {
            callback(newTime)
        }
    }
    
    func simulatePlaybackEnd() async {
        currentTimeValue = durationValue
        isPlayingValue = false
        for (_, callback) in timeObservers {
            callback(durationValue)
        }
    }
    
    func simulateError(_ error: Error) async {
        // Notify error handlers if implemented
    }
}
```

### Network Service Mock

```swift
// Updated mock API client with actor isolation
actor MockAPIClient: APIClient {
    // Test configuration
    var metadataToReturn: ArchiveMetadata?
    var videoURLToReturn: URL?
    var errorToThrow: Error?
    var requestDelay: TimeInterval = 0 // Simulate network delay
    
    // Test instrumentation
    private(set) var fetchMetadataCallCount = 0
    private(set) var fetchVideoURLCallCount = 0
    private(set) var lastRequestedIdentifier: String?
    private(set) var lastRequestedFile: ArchiveFile?
    
    func fetchMetadata(for identifier: String) async throws -> ArchiveMetadata {
        fetchMetadataCallCount += 1
        lastRequestedIdentifier = identifier
        
        // Simulate network delay
        if requestDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(requestDelay * 1_000_000_000))
        }
        
        // Simulate error
        if let error = errorToThrow {
            throw error
        }
        
        // Return configured metadata or create default
        return metadataToReturn ?? createDefaultMetadata(for: identifier)
    }
    
    func fetchVideoURL(for file: ArchiveFile) async throws -> URL {
        fetchVideoURLCallCount += 1
        lastRequestedFile = file
        
        // Simulate network delay
        if requestDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(requestDelay * 1_000_000_000))
        }
        
        // Simulate error
        if let error = errorToThrow {
            throw error
        }
        
        // Return configured URL or create default
        return videoURLToReturn ?? URL(string: "https://example.com/\(file.name)")!
    }
    
    // Helper methods for creating test data
    private func createDefaultMetadata(for identifier: String) -> ArchiveMetadata {
        ArchiveMetadata(
            metadata: ItemMetadata(
                identifier: identifier,
                title: "Test Video \(identifier)",
                description: "Test description for \(identifier)",
                creator: "Test Creator",
                date: "2023"
            ),
            files: [
                ArchiveFile(name: "test_video.mp4", format: "MPEG4", size: "10000000"),
                ArchiveFile(name: "test_video.avi", format: "AVI", size: "20000000")
            ]
        )
    }
    
    // Test helper methods
    func reset() {
        metadataToReturn = nil
        videoURLToReturn = nil
        errorToThrow = nil
        requestDelay = 0
        fetchMetadataCallCount = 0
        fetchVideoURLCallCount = 0
        lastRequestedIdentifier = nil
        lastRequestedFile = nil
    }
}
```

## Implementation Example with Proper Dependency Injection

Here's a concrete example showing a proper refactoring of the VideoPlayerViewModel with dependency injection:

```swift
// Service factory for centralized dependency management
class ServiceFactory {
    // Singleton instance with default implementations
    static let shared = ServiceFactory()
    
    // Core services with default implementations
    lazy var apiClient: APIClient = URLSessionAPIClient()
    lazy var mediaPlayer: MediaPlayer = AVFoundationMediaPlayer()
    lazy var cacheManager: VideoCacheManager = FilesystemVideoCacheManager()
    lazy var preloadService: PreloadService = DefaultPreloadService(
        apiClient: apiClient,
        cacheManager: cacheManager
    )
    
    // Factory methods to create objects with injected dependencies
    func createVideoPlayerViewModel() -> VideoPlayerViewModel {
        return VideoPlayerViewModel(
            apiClient: apiClient,
            mediaPlayer: mediaPlayer,
            preloadService: preloadService,
            cacheManager: cacheManager
        )
    }
    
    // Create a test factory with mock dependencies
    static func createTestFactory() -> ServiceFactory {
        let factory = ServiceFactory()
        factory.apiClient = MockAPIClient()
        factory.mediaPlayer = MockMediaPlayer()
        factory.cacheManager = MockVideoCacheManager()
        factory.preloadService = MockPreloadService()
        return factory
    }
}

// Refactored ViewModel with dependency injection
@MainActor
class VideoPlayerViewModel: BaseVideoViewModel, ObservableObject {
    // Dependencies
    private let apiClient: APIClient
    private let mediaPlayer: MediaPlayer
    private let preloadService: PreloadService
    private let cacheManager: VideoCacheManager
    
    // Published state
    @Published var currentMetadata: ArchiveMetadata?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Other properties...
    
    // Initializer with dependency injection
    init(
        apiClient: APIClient,
        mediaPlayer: MediaPlayer,
        preloadService: PreloadService,
        cacheManager: VideoCacheManager
    ) {
        self.apiClient = apiClient
        self.mediaPlayer = mediaPlayer
        self.preloadService = preloadService
        self.cacheManager = cacheManager
        
        super.init()
        setupObservers()
    }
    
    // Convenience initializer that uses the default service factory
    convenience init() {
        self.init(
            apiClient: ServiceFactory.shared.apiClient,
            mediaPlayer: ServiceFactory.shared.mediaPlayer,
            preloadService: ServiceFactory.shared.preloadService,
            cacheManager: ServiceFactory.shared.cacheManager
        )
    }
    
    // Methods using the injected dependencies
    func loadVideo(identifier: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let metadata = try await apiClient.fetchMetadata(for: identifier)
            guard let videoFile = metadata.files.first(where: { $0.format == "MPEG4" }) else {
                throw NSError(domain: "VideoPlayerViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "No compatible video file found"])
            }
            
            let videoURL = try await apiClient.fetchVideoURL(for: videoFile)
            await mediaPlayer.replaceCurrentItem(with: videoURL)
            await mediaPlayer.play()
            
            currentMetadata = metadata
            isLoading = false
        } catch {
            errorMessage = "Failed to load video: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // Other methods...
}

// Example of using the ViewModel in SwiftUI
struct VideoPlayerView: View {
    @StateObject var viewModel: VideoPlayerViewModel
    
    init(viewModel: VideoPlayerViewModel? = nil) {
        // Use provided viewModel or create one with default dependencies
        _viewModel = StateObject(wrappedValue: viewModel ?? ServiceFactory.shared.createVideoPlayerViewModel())
    }
    
    var body: some View {
        // View implementation...
    }
}

// Example test using dependency injection
/*
func testVideoLoading() async {
    // Create test factory with mock dependencies
    let factory = ServiceFactory.createTestFactory()
    
    // Configure mocks for this test
    let mockAPIClient = factory.apiClient as! MockAPIClient
    let mockMediaPlayer = factory.mediaPlayer as! MockMediaPlayer
    
    // Create test metadata
    let testMetadata = ArchiveMetadata(
        metadata: ItemMetadata(
            identifier: "test123",
            title: "Test Video",
            description: "Test Description",
            creator: "Test Creator",
            date: "2023"
        ),
        files: [
            ArchiveFile(name: "test.mp4", format: "MPEG4", size: "10000000")
        ]
    )
    
    // Configure the mock to return test data
    await mockAPIClient.metadataToReturn = testMetadata
    await mockAPIClient.videoURLToReturn = URL(string: "https://example.com/test.mp4")
    
    // Create view model with test dependencies
    let viewModel = VideoPlayerViewModel(
        apiClient: factory.apiClient,
        mediaPlayer: factory.mediaPlayer,
        preloadService: factory.preloadService,
        cacheManager: factory.cacheManager
    )
    
    // Execute the function under test
    await viewModel.loadVideo(identifier: "test123")
    
    // Verify expectations
    assert(await mockAPIClient.fetchMetadataCallCount == 1)
    assert(await mockAPIClient.lastRequestedIdentifier == "test123")
    assert(await mockMediaPlayer.playCallCount == 1)
    assert(viewModel.currentMetadata?.metadata.identifier == "test123")
    assert(viewModel.isLoading == false)
    assert(viewModel.errorMessage == nil)
}
*/
```

## Next Steps

1. Review and approve this updated architectural plan
2. Create a detailed implementation timeline
3. Begin implementing phase 1 with core abstractions
4. Run tests frequently to ensure functionality is maintained
5. Gradually migrate existing tests to the new approach
6. Pay particular attention to actor isolation and UI adapter patterns