# Refactoring Plan for Testing Improvements

## Problem Statement

The current testing approach has the following issues:

- Tests play actual video and audio during execution
- UI components are rendered during testing
- Real network requests are made to fetch data
- Tests are slow due to these real-world interactions
- It's difficult to test specific edge cases and error conditions
- Swift actors and concurrency add complexity to the testing approach
- Current implementation lacks protocol-based design and proper dependency injection
- Services are directly instantiated in ViewModels rather than being injected

## Goals

1. Make unit tests fast and predictable
2. Focus on testing business logic in isolation
3. Eliminate UI rendering during tests
4. Eliminate actual video playback during tests
5. Eliminate real network requests during tests
6. Enable simulating edge cases and error conditions
7. Maintain high test coverage and confidence
8. Handle Swift actor isolation correctly in abstractions
9. Avoid using Actor keyword - instead use async/await where possible
10. Implement proper protocol-based architecture with dependency injection
11. Restructure ViewModels to accept dependencies through initializers

## Current Architecture Problems

Our current implementation has significant testing challenges:

1. **Direct Instantiation of Dependencies**: Services are directly instantiated in ViewModels, making it impossible to inject test implementations.

2. **Concrete Type Usage**: Services are referenced by their concrete types rather than by protocols, tightly coupling implementation details.

3. **No Clear Service Boundaries**: Services have overlapping responsibilities and don't follow clear interface boundaries.

4. **Inheritance vs. Composition**: The codebase favors inheritance (e.g., BaseVideoViewModel) over composition, which makes isolated testing more difficult.

To achieve proper testability, we need to implement protocol-based dependency injection throughout the codebase.

## Protocol-Based Dependency Injection Approach

Our solution is to implement a comprehensive protocol-based dependency injection system throughout the codebase. This approach provides several benefits:

1. **Testability**: We can easily inject mock implementations for testing
2. **Modularity**: Components are decoupled and can be developed independently  
3. **Flexibility**: Implementations can be swapped without changing client code
4. **Readability**: Clearer understanding of a component's dependencies
5. **Maintainability**: Easier to refactor and extend the codebase

### Key considerations for Swift actors and async/await

- **Protocol Methods with Actors**: Methods in protocols need to be marked as `async` if they will be implemented by actor types.
- **Suspension Points**: Avoid suspension points in actor property accessors by moving complex operations to methods.
- **Protocol Design**: When an actor conforms to a protocol, all isolated methods need to be marked `async` in the protocol definition.

### Abstracting External Dependencies

- **AVFoundation Abstraction**: Create protocol interfaces for AVFoundation components that don't expose concrete types like `AVPlayer`.
- **Value Types at Boundaries**: Use simple value types (like `Double` for time) rather than complex types like `CMTime`.
- **UI Adapter Pattern**: Implement adapters that bridge between UI components and abstracted interfaces.
- **Separation of Concerns**: Each protocol should focus on a single responsibility.

### Dependency Injection Strategy

- **Constructor Injection**: All dependencies provided through initializers
- **Service Locator/Factory**: Create factory classes to simplify dependency management
- **Default Implementations**: Provide convenience initializers with default implementations
- **Shared Dependencies**: Carefully manage dependencies that need to be shared

## Implementation Plan

We'll implement a comprehensive dependency injection and abstraction system using these patterns:

1. **Protocol-Based Architecture**: Define protocols for all service interfaces
2. **Dependency Injection**: Inject dependencies rather than creating them internally
3. **Wrapper/Adapter Pattern**: Create wrappers around external frameworks
4. **Repository Pattern**: Abstract data access behind repository interfaces
5. **Factory Pattern**: Create object instances with appropriate dependencies

## Core Services to Abstract

### 1. Video Playback Layer

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

### 2. Network and API Layer

```
NetworkService (Protocol)
├── URLSessionNetworkService (Production Implementation)
└── MockNetworkService (Test Implementation)

ArchiveAPIClient (Protocol)
├── LiveArchiveAPIClient (Production Implementation)
└── MockArchiveAPIClient (Test Implementation)
```

**Key Interfaces**:

- `NetworkService`: Low-level network operations
- `ArchiveAPIClient`: High-level Archive.org API operations
- `MetadataProvider`: Retrieve and process metadata

### 3. Data Storage Layer

```
IdentifierRepository (Protocol)
├── SQLiteIdentifierRepository (Production Implementation)
└── InMemoryIdentifierRepository (Test Implementation)

CollectionPreferencesStore (Protocol)
├── UserDefaultsCollectionStore (Production Implementation)
└── InMemoryCollectionStore (Test Implementation)
```

### 4. Caching and Preloading Services

```
CacheService (Protocol)
├── FilesystemCacheService (Production Implementation)
└── InMemoryCacheService (Test Implementation)

PreloadService (Protocol)
├── StandardPreloadService (Production Implementation)
└── MockPreloadService (Test Implementation)
```

### 5. View Model Refactoring

```
VideoPlayerViewModel
└── Dependencies:
    ├── ArchiveAPIClient
    ├── MediaPlayer
    ├── CacheService
    ├── PreloadService
    └── IdentifierRepository
```

## Implementation Example

### Before: Direct instantiation without dependency injection

```swift
class VideoPlayerViewModel: BaseVideoViewModel, VideoProvider {
    // Services directly instantiated as properties
    let archiveService = ArchiveService()
    let cacheManager = VideoCacheManager()
    private let preloadService = PreloadService()
    private lazy var videoLoadingService = VideoLoadingService(
        archiveService: archiveService,
        cacheManager: cacheManager
    )
    
    // ...
}
```

### After: Protocol-based dependency injection

First, we define protocols for our services:

```swift
// Video loading service protocol
protocol VideoLoadingServiceProtocol {
    func loadIdentifiers() async throws -> [ArchiveIdentifier]
    func loadIdentifiersWithUserPreferences() async throws -> [ArchiveIdentifier]
    func loadRandomVideo() async throws -> (identifier: String, collection: String, title: String, description: String, asset: AVAsset, startPosition: Double)
}

// Archive service protocol
protocol ArchiveServiceProtocol {
    func loadArchiveIdentifiers() async throws -> [ArchiveIdentifier]
    func loadIdentifiersForCollection(_ collection: String) async throws -> [ArchiveIdentifier]
    func fetchMetadata(for identifier: String) async throws -> ArchiveMetadata
    func findPlayableFiles(in metadata: ArchiveMetadata) async -> [ArchiveFile]
    func getFileDownloadURL(for file: ArchiveFile, identifier: String) async -> URL?
    func getRandomIdentifier(from identifiers: [ArchiveIdentifier]) async -> ArchiveIdentifier?
    func estimateDuration(fromFile file: ArchiveFile) async -> Double
}

// Cache manager protocol
protocol VideoCacheManagerProtocol {
    func cacheCount() async -> Int
    func removeFirstCachedVideo() async -> CachedVideo?
    func addVideoToCache(_ video: CachedVideo) async
    func clearCache() async
}

// Preload service protocol
protocol PreloadServiceProtocol {
    func ensureVideosAreCached(cacheManager: VideoCacheManagerProtocol, archiveService: ArchiveServiceProtocol, identifiers: [ArchiveIdentifier]) async
    func cancelPreloading() async
}
```

Then, refactor the ViewModel to use dependency injection:

```swift
@MainActor
class VideoPlayerViewModel: BaseVideoViewModel, VideoProvider {
    // Dependencies injected through initializer
    private let archiveService: ArchiveServiceProtocol
    private let cacheManager: VideoCacheManagerProtocol
    private let preloadService: PreloadServiceProtocol
    private let videoLoadingService: VideoLoadingServiceProtocol
    let favoritesManager: FavoritesManager
    
    // Published properties remain the same
    @Published var isInitializing = true
    
    // Other properties...
    
    // Dependency injection through initializer
    init(
        archiveService: ArchiveServiceProtocol,
        cacheManager: VideoCacheManagerProtocol,
        preloadService: PreloadServiceProtocol,
        videoLoadingService: VideoLoadingServiceProtocol,
        favoritesManager: FavoritesManager
    ) {
        self.archiveService = archiveService
        self.cacheManager = cacheManager
        self.preloadService = preloadService
        self.videoLoadingService = videoLoadingService
        self.favoritesManager = favoritesManager
        
        super.init()
        
        // Setup tasks
        setupInitialLoading()
    }
    
    // Convenience initializer with default implementations
    convenience init(favoritesManager: FavoritesManager) {
        let archiveService = ArchiveService()
        let cacheManager = VideoCacheManager()
        let preloadService = PreloadService()
        let videoLoadingService = VideoLoadingService(
            archiveService: archiveService,
            cacheManager: cacheManager
        )
        
        self.init(
            archiveService: archiveService,
            cacheManager: cacheManager,
            preloadService: preloadService,
            videoLoadingService: videoLoadingService,
            favoritesManager: favoritesManager
        )
    }
    
    // Rest of the implementation...
}
```

### Service Factory to simplify dependency management

```swift
// Service factory to centralize dependency creation
class ServiceFactory {
    // Singleton instance for app-wide use
    static let shared = ServiceFactory()
    
    // Core services
    let archiveService: ArchiveServiceProtocol
    let cacheManager: VideoCacheManagerProtocol
    let preloadService: PreloadServiceProtocol
    let favoritesManager: FavoritesManager
    
    private init() {
        // Create default implementations
        self.archiveService = ArchiveService()
        self.cacheManager = VideoCacheManager()
        self.preloadService = PreloadService()
        self.favoritesManager = FavoritesManager()
    }
    
    // Factory method for VideoLoadingService
    func createVideoLoadingService() -> VideoLoadingServiceProtocol {
        return VideoLoadingService(
            archiveService: archiveService,
            cacheManager: cacheManager
        )
    }
    
    // Factory method for VideoPlayerViewModel
    func createVideoPlayerViewModel() -> VideoPlayerViewModel {
        return VideoPlayerViewModel(
            archiveService: archiveService,
            cacheManager: cacheManager,
            preloadService: preloadService,
            videoLoadingService: createVideoLoadingService(),
            favoritesManager: favoritesManager
        )
    }
    
    // Create a test factory with mock implementations
    static func createTestFactory() -> ServiceFactory {
        let factory = ServiceFactory()
        // Replace services with mock implementations for testing
        return factory
    }
}
```

### Example test using dependency injection with Swift Testing

```swift
@MainActor
@Test
func testLoadRandomVideo_updatesState() async throws {
    // Arrange - create mock implementations
    let mockArchiveService = MockArchiveService()
    let mockCacheManager = MockVideoCacheManager()
    let mockVideoLoadingService = MockVideoLoadingService()
    let mockPreloadService = MockPreloadService()
    let favoritesManager = FavoritesManager()
    
    // Configure mock behavior
    mockVideoLoadingService.mockRandomVideo = (
        identifier: "test1", 
        collection: "collection1",
        title: "Test Video",
        description: "Test description for video",
        asset: AVURLAsset(url: URL(string: "https://example.com/test.mp4")!),
        startPosition: 10.0
    )
    
    // Create view model with injected mocks
    let viewModel = VideoPlayerViewModel(
        archiveService: mockArchiveService,
        cacheManager: mockCacheManager,
        preloadService: mockPreloadService,
        videoLoadingService: mockVideoLoadingService,
        favoritesManager: favoritesManager
    )
    
    // Act
    await viewModel.loadRandomVideo()
    
    // Assert
    #expect(viewModel.currentIdentifier == "test1")
    #expect(viewModel.currentCollection == "collection1")
    #expect(viewModel.currentTitle == "Test Video")
    #expect(viewModel.currentDescription == "Test description for video")
    #expect(mockVideoLoadingService.loadRandomVideoCalled)
}
```

## Examples of Mock Implementations

### Mock Video Loading Service

```swift
class MockVideoLoadingService: VideoLoadingServiceProtocol {
    // Test configuration
    var mockIdentifiers: [ArchiveIdentifier] = []
    var mockRandomVideo: (identifier: String, collection: String, title: String, description: String, asset: AVAsset, startPosition: Double)?
    var shouldThrowError = false
    var error = NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
    
    // Call tracking
    var loadIdentifiersCalled = false
    var loadIdentifiersWithUserPreferencesCalled = false
    var loadRandomVideoCalled = false
    
    func loadIdentifiers() async throws -> [ArchiveIdentifier] {
        loadIdentifiersCalled = true
        
        if shouldThrowError {
            throw error
        }
        
        return mockIdentifiers
    }
    
    func loadIdentifiersWithUserPreferences() async throws -> [ArchiveIdentifier] {
        loadIdentifiersWithUserPreferencesCalled = true
        
        if shouldThrowError {
            throw error
        }
        
        return mockIdentifiers
    }
    
    func loadRandomVideo() async throws -> (identifier: String, collection: String, title: String, description: String, asset: AVAsset, startPosition: Double) {
        loadRandomVideoCalled = true
        
        if shouldThrowError {
            throw error
        }
        
        if let mockVideo = mockRandomVideo {
            return mockVideo
        }
        
        // Default mock response
        let identifier = "default_test_id"
        let collection = "default_test_collection"
        let title = "Default Test Video"
        let description = "Default test description"
        let asset = AVURLAsset(url: URL(string: "https://example.com/default.mp4")!)
        let startPosition = 0.0
        
        return (identifier, collection, title, description, asset, startPosition)
    }
    
    func reset() {
        mockIdentifiers = []
        mockRandomVideo = nil
        shouldThrowError = false
        loadIdentifiersCalled = false
        loadIdentifiersWithUserPreferencesCalled = false
        loadRandomVideoCalled = false
    }
}
```

### Mock Media Player

```swift
class MockMediaPlayer: MediaPlayerProtocol {
    // State properties
    private(set) var isPlayingValue = false
    private(set) var currentTimeValue = 0.0
    private(set) var durationValue = 120.0
    private(set) var currentAsset: AVAsset?
    
    // Test tracking
    var playCallCount = 0
    var pauseCallCount = 0
    var seekCallCount = 0
    var replaceAssetCallCount = 0
    
    // Protocol implementation
    var isPlaying: Bool { isPlayingValue }
    var currentTime: Double { currentTimeValue }
    var duration: Double { durationValue }
    
    func play() {
        isPlayingValue = true
        playCallCount += 1
    }
    
    func pause() {
        isPlayingValue = false
        pauseCallCount += 1
    }
    
    func seek(to time: Double) {
        currentTimeValue = time
        seekCallCount += 1
    }
    
    func replaceCurrentAsset(_ asset: AVAsset?) {
        currentAsset = asset
        currentTimeValue = 0
        replaceAssetCallCount += 1
    }
    
    // Test helper methods
    func simulateTimeChange(to time: Double) {
        currentTimeValue = time
    }
    
    func simulatePlaybackFinished() {
        currentTimeValue = durationValue
        isPlayingValue = false
    }
    
    func reset() {
        isPlayingValue = false
        currentTimeValue = 0
        playCallCount = 0
        pauseCallCount = 0
        seekCallCount = 0
        replaceAssetCallCount = 0
        currentAsset = nil
    }
}
```

## Implementation Strategy

### Phase 1: Define Protocols

1. Define protocols for all service interfaces
2. Ensure protocol methods match actor isolation requirements
3. Create mock implementations for testing

### Phase 2: Refactor Services

1. Update existing service implementations to conform to protocols
2. Add factory methods for creating services
3. Create a ServiceFactory to centralize dependency creation

### Phase 3: Refactor ViewModels

1. Update ViewModels to accept dependencies through initializers
2. Add convenience initializers that use the ServiceFactory
3. Update SwiftUI views to use the new ViewModel initializers

### Phase 4: Update Tests

1. Create a comprehensive test suite using Swift Testing framework
2. Test edge cases and error conditions
3. Verify all functionality works as expected with mocks

## Best Practices for Protocol-Based Testing

1. **Interface Segregation**: Keep protocols focused and minimal
2. **Testability First**: Design with testing in mind from the start
3. **Clear Boundaries**: Define clear service boundaries
4. **Consistent Naming**: Use consistent naming conventions
5. **Default Implementations**: Provide convenience methods for common use cases
6. **Factory Methods**: Use factory methods to create objects with dependencies
7. **Test Doubles**: Create appropriate test doubles (mocks, stubs, fakes)
8. **Realistic Test Data**: Use realistic test data in mock implementations

## Next Steps

1. Review and approve this architectural plan
2. Begin implementing core protocols and abstractions
3. Update services to implement the new protocols
4. Refactor ViewModels to use dependency injection
5. Create and enhance test suite using the Swift Testing framework