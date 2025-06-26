# Convert to Combine - Implementation Plan

## Overview
This document outlines a phased approach to convert LostArchiveTV's reactive patterns to use Combine framework where appropriate, with a focus on modernizing the codebase while maintaining testability and code clarity.

**Current Status**: Phase 2 completed (2025-06-26) - Simple notification conversions successfully migrated to Combine.

## Current State Analysis

### Existing Combine Usage
- **Minimal Direct Usage**: Only `PreloadingIndicatorManager` directly imports Combine
- **SwiftUI Integration**: Heavy use of `@Published` properties and `ObservableObject`
- **Timer.publish**: Used in `RetroEdgePreloadIndicator` for animations

### Patterns to Convert
1. **NotificationCenter** - 30+ occurrences across the codebase
2. **Completion Handlers** - Video trimming, downloads, saving operations
3. **Timer-based Updates** - Playhead position updates, animations
4. **URLSession Operations** - Download progress tracking
5. **DispatchQueue Operations** - UI updates currently using `.async`

## Recommendations

### ✅ RECOMMENDED - High Value Conversions

#### 1. NotificationCenter → Combine Publishers
**Why**: Clean reactive pattern, better type safety, easier testing
- Cache status notifications
- Preloading notifications
- Preset reload notifications

#### 2. Download Progress Tracking
**Why**: Combine's progress publishers are perfect for this use case
- Video downloads with progress
- Export operations

#### 3. Timer-based Updates
**Why**: Timer.publish is cleaner than scheduledTimer
- Video playhead position updates
- Animation timers

#### 4. Simple Completion Handlers
**Why**: Future/Promise pattern is cleaner for one-shot operations
- Video trimming operations
- Save to Photos operations

### ⚠️ CONSIDER CAREFULLY - Medium Complexity

#### 1. AVPlayer Notifications
**Why**: Some complexity with AVFoundation integration
- Player item end notifications
- Player status observations

#### 2. Complex State Management
**Why**: May require significant refactoring
- Video transition flows
- Cache management state

### ❌ NOT RECOMMENDED - Too Complex/Low Value

#### 1. Async/Await Functions
**Why**: Already modern Swift concurrency, conversion adds no value
- 65+ files use async/await effectively
- Converting to Combine would reduce readability

#### 2. Core SwiftUI Property Wrappers
**Why**: Already using Combine under the hood
- `@Published`, `@ObservedObject` working well
- No need to change

#### 3. Complex Service Interactions
**Why**: Would require extensive mocking infrastructure
- OpenAI/Pinecone service calls
- Database operations

## Phased Implementation Plan

### Phase 1: Foundation & Testing Infrastructure
**Timeline**: 1 week

#### 1.1 Create Combine Testing Utilities
```swift
// Create test helpers for Combine publishers
// Support for Swift Testing framework with async/await
// Mock publisher creators
// Expectation helpers
```

#### 1.2 Write Tests for Existing Notification Patterns
- Test current NotificationCenter usage
- Document expected behaviors
- Create baseline for regression testing

### Phase 2: Simple Notification Conversions ✅ COMPLETED
**Timeline**: 1 week (Completed 2025-06-26)

#### 2.1 Convert Cache Status Notifications ✅
**Files Updated**:
- `VideoCacheService+Notifications.swift`
- `BaseVideoViewModel.swift`
- `PreloadingIndicatorManager.swift`

**Testing Completed**:
- Cache status updates propagate correctly
- Multiple subscribers receive updates
- Thread safety verified

#### 2.2 Convert Preloading Notifications ✅
**Files Updated**:
- `TransitionPreloadManager.swift`
- `VideoTransitionManager+CacheHandling.swift`

#### 2.3 Additional Notifications Converted ✅
**Navigation and UI Notifications**:
- `showSimilarVideos` → `NavigationService.similarVideosPublisher`
  - Converted from NotificationCenter to Combine publisher
  - Improved type safety with direct SimilarVideo parameter
  - Eliminated string-based notification names

- `startVideoTrimming` → `VideoEditingService.startVideoTrimmingPublisher`
  - Converted completion handler pattern to Combine
  - Better integration with SwiftUI views
  - Cleaner subscription management

**Data Update Notifications**:
- `ReloadIdentifiers` → `PresetManager.identifierReloadPublisher`
  - Converted from NotificationCenter to PassthroughSubject
  - Centralized identifier reload notifications
  - Better coordination between preset changes and UI updates

#### Patterns and Lessons Learned:
1. **Service-based Publishers**: Creating dedicated publishers in service classes (NavigationService, VideoEditingService) provides better encapsulation and type safety
2. **PassthroughSubject vs CurrentValueSubject**: Used PassthroughSubject for event-based notifications that don't need to retain state
3. **Main Thread Delivery**: Used `.receive(on: DispatchQueue.main)` for UI-bound publishers to ensure SwiftUI updates happen on the main thread
4. **Subscription Management**: Stored subscriptions in `Set<AnyCancellable>` within ViewModels for automatic cleanup
5. **Testing Benefits**: Combine publishers made testing more deterministic with async/await patterns

### Phase 3: Timer and Progress Conversions
**Timeline**: 1 week

#### 3.1 Convert Timer-based Updates
**Files to Update**:
- `VideoTrimViewModel+PlaybackControl.swift` (playhead timer)

**Testing Requirements**:
- Test timer cancellation
- Test update frequency
- Test memory leaks

#### 3.2 Convert Download Progress
**Files to Update**:
- `VideoDownloadService.swift`
- `VideoSaveManager.swift`
- `TrimDownloadView.swift`

**Testing Requirements**:
- Mock URLSession progress
- Test progress updates
- Test cancellation

### Phase 4: Completion Handler Conversions
**Timeline**: 1 week

#### 4.1 Convert Simple Completion Handlers
**Files to Update**:
- `VideoTrimManager.swift` (trimVideo)
- `PlayerManager+Playback.swift` (seek operations)

**Testing Requirements**:
- Test success/failure cases
- Test cancellation
- Test threading

### Phase 5: Complex State Management (Optional)
**Timeline**: 2 weeks

#### 5.1 Evaluate Conversion Benefits
- Measure code complexity reduction
- Assess testing improvements
- Consider maintenance implications

## Testing Strategy

### Test-First Approach
1. **Write tests for current behavior** before any changes
2. **Use Swift Testing framework** with async/await patterns
3. **No mock objects** - use test implementations like existing tests

### Testing Patterns

#### For NotificationCenter Conversions:
```swift
@Test
func cacheStatusUpdate_propagatesToSubscribers() async {
    // Create publisher
    let cacheService = VideoCacheService()
    
    // Subscribe and collect values
    await withCheckedContinuation { continuation in
        cacheService.cacheStatusPublisher
            .sink { status in
                #expect(status == .ready)
                continuation.resume()
            }
            .store(in: &cancellables)
    }
}
```

#### For Timer Conversions:
```swift
@Test
func playheadTimer_updatesAtCorrectFrequency() async {
    let viewModel = VideoTrimViewModel()
    var updateCount = 0
    
    viewModel.playheadPublisher
        .sink { _ in updateCount += 1 }
        .store(in: &cancellables)
    
    // Wait for updates
    try await Task.sleep(for: .seconds(1.1))
    
    #expect(updateCount >= 10) // Expecting ~10Hz updates
}
```

### Complex Testing Scenarios

#### 1. Multiple Subscribers
- Test that all subscribers receive updates
- Test subscription ordering
- Test late subscriptions

#### 2. Thread Safety
- Test concurrent subscriptions
- Test updates from background threads
- Test main thread delivery

#### 3. Memory Management
- Test subscription cleanup
- Test weak reference cycles
- Test cancellation

## Migration Guidelines

### Do's:
- ✅ Test current behavior first
- ✅ Convert one pattern at a time
- ✅ Use Combine for streams of values
- ✅ Use async/await for single operations
- ✅ Keep conversions focused and simple

### Don'ts:
- ❌ Don't convert async/await to Combine
- ❌ Don't create complex operator chains
- ❌ Don't convert working SwiftUI patterns
- ❌ Don't sacrifice readability for "purity"

## Success Metrics
- Reduced boilerplate code
- Improved testability
- Better type safety
- Maintained or improved performance
- No regression in functionality

## Remaining NotificationCenter Usage

### Intentionally Kept as NotificationCenter:
1. **CacheSystemNeedsRestart**
   - **Location**: `VideoCacheService+StateManagement.swift`
   - **Reason**: System-level notification that requires app restart
   - **Justification**: Rare event, doesn't benefit from Combine conversion

2. **AVPlayerItemDidPlayToEndTime**
   - **Location**: `PlayerManager+Monitoring.swift`, `BaseVideoViewModel.swift`
   - **Reason**: AVFoundation framework notification
   - **Justification**: Direct integration with AVFoundation, converting would add unnecessary abstraction layer

### Notifications Still to Convert (Future Phases):
1. **Player State Notifications**
   - Player readiness notifications
   - Playback error notifications
   - Consider in Phase 5 with complex state management

2. **Cache Update Notifications**
   - Individual cache item updates
   - Cache progress notifications
   - Consider combining with download progress in Phase 3

## Risk Mitigation
1. **Gradual rollout** - One component at a time
2. **Comprehensive testing** - Before and after each change
3. **Maintain fallback patterns** - Keep NotificationCenter for system-level events
