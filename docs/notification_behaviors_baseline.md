# Notification Behaviors Baseline Documentation

This document establishes the baseline behavior for notifications in LostArchiveTV as of Phase 1 of the Combine conversion project. These behaviors are tested and verified to ensure no regression during the conversion.

## Core Notifications

### 1. Preloading Notifications

#### `preloadingStarted`
- **Posted by**: `VideoCacheService.notifyCachingStarted()`
- **Posted on**: Main thread
- **Purpose**: Signals that video caching/preloading has begun
- **Observers**: 
  - `PreloadingIndicatorManager` - Updates state to `.preloading`
- **Expected Behavior**: 
  - Notification is posted on main thread
  - Multiple subscribers all receive the notification
  - PreloadingIndicatorManager only changes state if not already `.preloaded`

#### `preloadingCompleted`
- **Posted by**: `VideoCacheService.notifyCachingCompleted()`
- **Posted on**: Main thread
- **Purpose**: Signals that video caching/preloading has finished
- **Observers**:
  - `PreloadingIndicatorManager` - Triggers state update check
- **Expected Behavior**:
  - Notification is posted on main thread
  - Triggers `updateStateFromTransitionManager()` call
  - State update depends on TransitionManager's `nextVideoReady` property

### 2. Cache Status Notifications

#### `CacheStatusChanged`
- **Posted by**: 
  - `VideoTransitionManager+NextTransition` (line 185)
  - `VideoTransitionManager+PreviousTransition` (line 183)
  - `TransitionPreloadManager` (multiple locations)
- **Posted on**: Main thread
- **Purpose**: Signals that cache status has changed (videos ready, loading, etc.)
- **Observers**:
  - `PreloadingIndicatorManager` - Updates indicator state
  - `BaseVideoViewModel` - Updates cache status properties
  - `BottomInfoPanel` - Updates UI display
- **Expected Behavior**:
  - Posted when video cache state changes
  - Triggers UI updates for cache indicators
  - Multiple observers handle the same notification

### 3. Preset/Identifier Notifications

#### `ReloadIdentifiers`
- **Posted by**: `PresetManager` when:
  - Adding identifier to preset (`addIdentifier`)
  - Removing identifier from preset (`removeIdentifier`)
  - Adding identifier to specific preset (`addIdentifier:toPresetWithId:`)
- **Posted on**: Current thread (synchronous)
- **Purpose**: Signals that preset identifiers have changed
- **Observers**:
  - View models that need to reload video lists
  - UI components showing identifier counts
- **Expected Behavior**:
  - Posted only when identifier actually changes (not for duplicates)
  - Not posted when trying to remove non-existent identifier
  - Each operation posts one notification

## Testing Coverage

### Phase 1 Tests Created:

1. **CombineTestingUtilities.swift**
   - Helper functions for testing Combine publishers
   - Value collectors and recorders
   - Mock publisher creators
   - Async/await integration helpers

2. **VideoCacheServiceTests.swift**
   - Tests for `preloadingStarted` notification posting
   - Tests for `preloadingCompleted` notification posting
   - Verification of main thread posting
   - Multiple subscriber tests

3. **PreloadingIndicatorManagerTests.swift**
   - State transition tests
   - Notification response tests
   - Published property change tests
   - Thread safety verification

4. **PresetManagerTests.swift**
   - `ReloadIdentifiers` notification tests
   - Add/remove identifier notification behavior
   - Duplicate handling tests
   - Multiple operation tests

## Thread Safety Considerations

All UI-affecting notifications are posted on the main thread:
- `preloadingStarted` and `preloadingCompleted` use `Task { @MainActor in ... }`
- `CacheStatusChanged` is posted from main thread contexts
- `ReloadIdentifiers` is posted synchronously on the calling thread

## Migration Notes

When converting to Combine:
1. Maintain main thread delivery for UI notifications
2. Ensure all subscribers receive notifications (multicast behavior)
3. Handle subscription cleanup properly to avoid memory leaks
4. Test thread safety with concurrent operations
5. Verify no duplicate notifications are sent
6. Maintain order of notification delivery where critical

## Known Edge Cases

1. **Rapid State Changes**: Multiple notifications in quick succession should be handled gracefully
2. **Late Subscribers**: Subscribers added after a notification may miss state updates
3. **Preset Selection**: Notifications depend on having a selected preset
4. **Cleanup**: Proper cancellable storage is critical to avoid memory leaks