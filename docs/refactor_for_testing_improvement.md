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

## Lessons Learned From Previous Refactoring Attempts

Our previous refactoring attempts (commits `af8e5b2` and `def51dd`) provided valuable insights:

1. **Protocol Design Challenges**:
   - Protocols need to be carefully designed to cover all necessary functionality
   - ObservableObject protocol requirements need special handling with generics
   - Property wrappers like @Published cannot be part of protocols directly

2. **Dependency Injection Complexity**:
   - Managing many injected dependencies can lead to unwieldy initializers
   - A centralized ServiceFactory pattern helps simplify dependency management
   - Careful consideration needed for shared vs. recreated dependencies

3. **Actor Isolation Issues**:
   - Converting actors to regular classes with async/await can lead to concurrency issues
   - @MainActor needs to be consistently applied across the codebase
   - Protocol methods that access actor state must be marked async

4. **Mock Implementation Challenges**:
   - Mocks need to track both call patterns and parameter values
   - Error simulation capabilities are critical for testing edge cases
   - Mock state needs to be resettable between tests for isolation
   - Default implementations help reduce boilerplate in mocks

5. **Testing Framework Integration**:
   - Swift Testing framework requires special syntax and patterns
   - Assertion methods need to align with testing framework capabilities
   - Test isolation and parallelization require careful planning

6. **View Model Protocol Design**:
   - Protocols extending ObservableObject have associated type complications
   - Published properties can only be implemented in concrete classes
   - Generic specialization is needed when working with protocol-typed view models

## Core Architecture Decisions

Based on our implementation attempts and industry best practices, we recommend the following architecture:

### 1. Protocol-Based Service Layer

Every service should have a corresponding protocol that defines its public API:

```swift
// Example protocol for a service
protocol ArchiveServiceProtocol {
    func loadArchiveIdentifiers() async throws -> [ArchiveIdentifier]
    func loadIdentifiersForCollection(_ collection: String) async throws -> [ArchiveIdentifier]
    func fetchMetadata(for identifier: String) async throws -> ArchiveMetadata
    // Additional methods...
}
```

### 2. ServiceFactory for Dependency Management

Use a ServiceFactory to centralize dependency creation and management:

```swift
@MainActor
protocol ServiceFactoryProtocol {
    // Core services as protocol types
    var archiveService: any ArchiveServiceProtocol { get }
    var cacheManager: any VideoCacheManagerProtocol { get }
    var preloadService: any PreloadServiceProtocol { get }
    
    // Factory methods
    func createVideoLoadingService() -> any VideoLoadingServiceProtocol
    func createVideoPlayerViewModel() -> VideoPlayerViewModel
    // Additional factory methods...
}

@MainActor
class ServiceFactory: ServiceFactoryProtocol {
    // Singleton instance
    static let shared = ServiceFactory()
    
    // Core services
    let archiveService: any ArchiveServiceProtocol
    let cacheManager: any VideoCacheManagerProtocol
    let preloadService: any PreloadServiceProtocol
    // Additional services...
    
    private init() {
        // Initialize concrete implementations
        self.archiveService = ArchiveService()
        self.cacheManager = VideoCacheManager()
        self.preloadService = PreloadService()
        // Initialize additional services...
    }
    
    // Factory methods
    func createVideoLoadingService() -> any VideoLoadingServiceProtocol {
        return VideoLoadingService(
            archiveService: archiveService,
            cacheManager: cacheManager
        )
    }
    
    // Additional factory methods...
}
```

### 3. Protocol-Based View Models

Define protocols for view models to enable dependency injection and testing:

```swift
@MainActor
protocol BaseVideoViewModelProtocol: ObservableObject {
    // Properties
    var player: AVPlayer? { get set }
    var isPlaying: Bool { get }
    var errorMessage: String? { get set }
    
    // Methods
    func pausePlayback()
    func resumePlayback()
    func restartVideo()
    // Additional methods...
}
```

### 4. Mock Implementations for Testing

Create comprehensive mock implementations of all service protocols:

```swift
class MockVideoCacheManager: VideoCacheManagerProtocol {
    // Mock state
    private var cachedVideos: [CachedVideo] = []
    private var maxCacheSize: Int = 3
    
    // Call tracking
    var getCachedVideosCallCount = 0
    var addCachedVideoCallCount = 0
    // Additional tracking properties...
    
    // Protocol implementation
    func getCachedVideos() async -> [CachedVideo] {
        getCachedVideosCallCount += 1
        return cachedVideos
    }
    
    // Additional implementations...
    
    // Reset for test isolation
    func reset() {
        cachedVideos.removeAll()
        getCachedVideosCallCount = 0
        // Reset additional tracking...
    }
}
```

### 5. Mock Service Factory for Tests

Create a specialized mock factory for testing:

```swift
@MainActor
class MockServiceFactory: ServiceFactoryProtocol {
    // Core mock services
    let archiveService: any ArchiveServiceProtocol
    let cacheManager: any VideoCacheManagerProtocol
    // Additional services...
    
    // Internal references to concrete mocks
    private let _mockArchiveService: MockArchiveService
    private let _mockCacheManager: MockVideoCacheManager
    // Additional private references...
    
    init() {
        // Create and configure mocks
        _mockArchiveService = MockArchiveService()
        _mockCacheManager = MockVideoCacheManager()
        // Create additional mocks...
        
        // Assign to protocol-typed properties
        archiveService = _mockArchiveService
        cacheManager = _mockCacheManager
        // Assign additional services...
    }
    
    // Accessors for test-specific capabilities
    var mockArchiveService: MockArchiveService { _mockArchiveService }
    var mockCacheManager: MockVideoCacheManager { _mockCacheManager }
    // Additional accessors...
    
    // Factory methods
    func createVideoLoadingService() -> any VideoLoadingServiceProtocol {
        return _mockVideoLoadingService
    }
    
    // Additional factory methods...
    
    // Reset all mocks for test isolation
    func resetAllMocks() {
        _mockArchiveService.reset()
        _mockCacheManager.reset()
        // Reset additional mocks...
    }
}
```

## Refactoring Plan

### Phase 1: Define Core Protocols

1. Define protocols for all services
   - Create a protocol file for each service (e.g., `ArchiveServiceProtocol.swift`)
   - Include all necessary methods and properties
   - Mark methods with `async` as needed for concurrency
   - Ensure protocols extend `ObservableObject` where necessary

2. Define the `ServiceFactoryProtocol`
   - Include access to all core services
   - Include factory methods for creating complex service combinations
   - Mark with `@MainActor` to ensure main thread conformance

3. Define view model protocols
   - Create base view model protocol (`BaseVideoViewModelProtocol`)
   - Create specialized view model protocols as needed
   - Ensure proper inheritance and composition

### Phase 2: Refactor Services

1. Update services to implement protocols
   - Make existing services conform to their respective protocols
   - Change actor-based services to regular classes using async/await
   - Add protocol conformance to service implementations
   - Ensure all methods specified in protocols are implemented

2. Update service interdependencies
   - Modify services to accept dependencies through initializers
   - Use protocol types rather than concrete implementations
   - Create convenience initializers for backward compatibility

3. Implement the `ServiceFactory`
   - Create the ServiceFactory class conforming to ServiceFactoryProtocol
   - Implement all factory methods
   - Initialize it as a singleton

### Phase 3: Refactor View Models

1. Update view models to use dependency injection
   - Convert direct service instantiation to dependency injection
   - Add initializers that accept protocol-typed dependencies
   - Create convenience initializers that use ServiceFactory

2. Implement protocol conformance
   - Make view models conform to their respective protocols
   - Ensure all protocol-required properties and methods are implemented
   - Maintain @Published properties in the implementation classes

3. Update view model interactions
   - Replace concrete type references with protocol types
   - Ensure asynchronous operations are properly handled
   - Make sure UI updates happen on the main thread

### Phase 4: Implement Mocks

1. Create mock implementations for all service protocols
   - Implement all protocol methods with controllable behavior
   - Add tracking for calls and parameters
   - Add capability to simulate errors and edge cases
   - Add reset functionality for test isolation

2. Create a `MockServiceFactory`
   - Implement all factory methods to return mock implementations
   - Add convenience methods for testing-specific operations
   - Add capabilities to control mock behavior globally

3. Create mock data generators
   - Add methods to generate realistic test data
   - Create utilities for common test scenarios
   - Ensure data consistency across tests

### Phase 5: Update SwiftUI Views

1. Update view initialization
   - Modify views to use the ServiceFactory for view model creation
   - Switch to dependency injection where necessary
   - Maintain backward compatibility with existing code

2. Add preview providers
   - Create preview-specific mock implementations
   - Use MockServiceFactory to provide realistic preview data
   - Create preview variants for different states

### Phase 6: Create Tests

1. Set up Swift Testing framework
   - Create new test files using Swift Testing
   - Replace existing XCTest files where applicable

2. Implement core service tests
   - Test each service in isolation
   - Use MockServiceFactory to provide dependencies
   - Test both success paths and error conditions

3. Implement view model tests
   - Test view models with mock services
   - Verify state changes and UI reactions
   - Test edge cases and error handling

## Specific Implementation Guidelines

### Protocol Design

1. **Observable Protocol Requirements**
   - Remember that protocols cannot contain @Published properties
   - Add getters and setters in protocols, implement with @Published in classes
   - Use `ObservableObject` protocol inheritance for view model protocols

2. **Handling Associated Types**
   - Be aware that `ObservableObject` has an associated type
   - Use generic constraints or type erasure when needed
   - Consider using the `any` keyword for protocol types in Swift 5.7+

3. **Protocol Extensions**
   - Use protocol extensions for default implementations
   - Avoid stateful computations in protocol extensions
   - Keep extensions focused on behavior, not state

### Dependency Injection

1. **Constructor Injection**
   - Pass all dependencies through initializers
   - Use protocol types rather than concrete implementations
   - Provide convenience initializers for backward compatibility

2. **ServiceFactory Pattern**
   - Use ServiceFactory to centralize dependency creation
   - Inject the factory itself when many dependencies are needed
   - Maintain singleton access for global access

3. **Environment Integration**
   - Consider using SwiftUI's environment for global dependencies
   - Create environment keys for service protocols
   - Use environment objects for shared state

### Testing Strategy

1. **Isolated Unit Tests**
   - Test each component in isolation with mock dependencies
   - Focus on business logic, not implementation details
   - Use descriptive test names that explain the scenario and expected outcome

2. **Mock Design**
   - Track method calls and parameters to verify behavior
   - Add controllable success/failure responses
   - Include reset functionality for test isolation
   - Add convenience methods for common scenarios

3. **Test Data Generation**
   - Create realistic test data that matches production scenarios
   - Use factory methods to build complex test objects
   - Maintain consistency between related test objects

4. **Assertion Patterns**
   - Use Swift Testing's `#expect` syntax for assertions
   - Include descriptive failure messages
   - Test both positive and negative scenarios

## Best Practices for Swift Concurrency

1. **@MainActor Usage**
   - Mark UI-related view models and services with @MainActor
   - Ensure published values are only modified on the main thread
   - Be conscious of actor isolation boundaries

2. **Async/Await Pattern**
   - Use async/await rather than completion handlers
   - Mark async methods correctly in protocols
   - Handle cancellation and errors appropriately

3. **Avoiding Actors**
   - Prefer regular classes with async/await to actors when possible
   - Use Task for background work rather than actor methods
   - Be mindful of shared mutable state

## Conclusion

This refactoring plan provides a comprehensive roadmap for implementing a testable, protocol-based architecture. By following these guidelines, we can achieve our goals of making tests faster, more predictable, and more comprehensive while improving the overall architecture of our application.

The key to success is implementing protocols consistently across the codebase, using dependency injection throughout, and creating a robust set of mock implementations for testing. The ServiceFactory pattern will simplify dependency management and make it easier to swap implementations for testing purposes.

Remember that this refactoring is substantial and should be approached incrementally. Start with core services, then move to view models and views. Each step should maintain app functionality while improving testability.