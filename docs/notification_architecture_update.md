# Notification Architecture Review and Update Plan

*Last Modified: May 14, 2025*

## Table of Contents
1. [Research Summary](#research-summary)
2. [Current Notification Usage](#current-notification-usage)
3. [Analysis and Recommendations](#analysis-and-recommendations)
4. [Implementation Priorities](#implementation-priorities)

## Research Summary

### Modern SwiftUI State Management

SwiftUI offers several approaches to state management, with some significant improvements in iOS 17+:

1. **ObservableObject Protocol (iOS 13+)**
   - Class-based approach using Combine framework
   - Requires `@Published` properties to trigger updates
   - Uses property wrappers like `@ObservedObject` and `@StateObject`
   - Triggers view updates when any `@Published` property changes, regardless of whether that property affects the view

2. **@Observable Macro (iOS 17+)**
   - Newer, more efficient approach that replaces ObservableObject
   - Doesn't require Combine framework
   - More granular updates - only redraws views that use the changed property
   - Better performance by preventing unnecessary view redraws
   - Works with `@State` instead of `@StateObject`

3. **Environment**
   - Used for dependency injection and shared state
   - Propagates automatically through the view hierarchy
   - Has limitations with modal views (sheets don't automatically receive environment objects)

4. **NotificationCenter**
   - Most traditional approach
   - Allows broadcasting events to multiple unrelated components
   - Useful for system events (like keyboard appearance) 
   - Decouples components but makes state management more complex
   - Requires manual subscription management

### Bottom Sheet Modal Best Practices

For bottom sheet implementation in SwiftUI:

1. **Modern Approach (iOS 16+)**
   - Use `.presentationDetents([.medium, .large])` modifier on sheet content
   - Control presentation with @State variables
   - Pass data directly to the presented view

2. **Data Flow**
   - Environment objects should be explicitly passed to modals
   - @State or @Binding for controlling presentation
   - Direct property passing for most view data

3. **Benefits of Moving from Notifications**
   - More predictable state management
   - Better type safety
   - Clearer data flow and component relationships
   - Improved testing capabilities
   - Reduced chance of memory leaks

## Current Notification Usage

The application uses NotificationCenter in several key areas, organized by notification type and purpose:

### UI Coordination Notifications

1. **PresetSelection Notifications**
   - `ShowPresetSelection` - Triggers the preset selection bottom sheet modal
   - `ClosePresetSelection` - Ensures all instances of preset selection are closed
   - `IdentifierSaved` - Provides feedback when an identifier is saved to a preset
   - Used in: `PresetSelectionView.swift`, `SwipeablePlayerView.swift`, `BaseVideoViewModel.swift`
   - **Recommendation**: Replace with sheet presentation state and direct data passing

2. **Video Navigation Notifications**
   - `showSimilarVideos` - Navigates to similar videos screen
   - Used in: `ContentView.swift`, `PlayerButtonPanel.swift`, `FavoritesVideoLayerContent.swift`
   - **Recommendation**: Replace with NavigationStack and programmatic navigation

3. **Trim Mode Notifications**
   - `startVideoTrimming` - Activates video trimming mode
   - Used in: `SwipeablePlayerView.swift`, `VideoGestureHandler.swift`, `FavoritesVideoLayerContent.swift`
   - **Recommendation**: Replace with view state and direct function calls

### Cache and Preloading State Notifications

1. **Cache Status Notifications**
   - `CacheStatusChanged` - Updates UI when cache status changes
   - `CacheSystemNeedsRestart` - Triggers cache system restart when stalled
   - Used in: `BaseVideoViewModel.swift`, `TransitionPreloadManager.swift`, `BottomInfoPanel.swift`, `PreloadingIndicatorManager+Notification.swift`
   - **Recommendation**: Create a shared observable cache state object

2. **Preloading Notifications**
   - `preloadingStarted` - Signals start of preloading operation
   - `preloadingCompleted` - Signals completion of preloading
   - Used in: `VideoCacheService+Notifications.swift`, `PreloadingIndicatorManager.swift`
   - **Recommendation**: Combine with cache status observable

### Data Refresh Notifications

1. **Identifier Management Notifications**
   - `ReloadIdentifiers` - Triggers reload of identifiers from storage
   - Used in: `UserSelectedIdentifiersManager.swift`, `HomeFeedSettingsViewModel.swift`
   - **Recommendation**: Create an observable identifiers service

### System Notifications

1. **AVPlayer Notifications**
   - `AVPlayerItemDidPlayToEndTime` - Handles playback completion
   - Used in: `VideoTrimViewModel+InitAndCleanup.swift`
   - **Recommendation**: Keep as-is (system notification)

## Analysis and Recommendations

### 1. Bottom Sheet Modal for Preset Selection

**Current Implementation**:

- Uses multiple notifications (`ShowPresetSelection`, `ClosePresetSelection`, `IdentifierSaved`)
- Coordination happens through notification handlers across multiple files
- Modal state and data flow are disconnected

**Recommendation**:

- Replace with a sheet presentation controlled by @State variables
- Pass data directly to the sheet view using initialization parameters
- Use completion callbacks or @Binding for result handling
- Create a central coordinator for preset management if needed

**Priority**: High - This implements the recently added feature and would be a good test case for the new approach

### 2. Cache Status Management

**Current Implementation**:

- Uses notifications (`CacheStatusChanged`, `preloadingStarted`, `preloadingCompleted`) for coordinating cache state changes
- Visualization indicators subscribe to these events

**Recommendation**:

- Create a centralized `CacheStateManager` as an @Observable object
- Maintain all cache status in this single source of truth
- Components directly observe this object instead of relying on notifications
- Could still use notifications for critical recovery situations like `CacheSystemNeedsRestart`

**Priority**: Medium - Complex interconnected system that would benefit from refactoring but requires careful testing

### 3. Video Navigation

**Current Implementation**:

- Uses notifications for navigation between different views (e.g., similar videos)
- Modal dismissal and presentation handled through notification system

**Recommendation**:

- Use NavigationStack and programmatic navigation
- Control navigation with @State variables
- Pass relevant data directly during navigation
- Implement proper view lifecycle management

**Priority**: Medium - Affects core navigation flow but likely less complex than cache system

### 4. Identifier Management

**Current Implementation**:

- `ReloadIdentifiers` notification triggers data refresh across components

**Recommendation**:

- Create an @Observable `IdentifierService` that manages identifiers
- Components directly subscribe to changes in this service
- Implement proper dependency injection through environment

**Priority**: Medium - Important for core functionality but smaller in scope

## Implementation Priorities

Based on the analysis, a phased implementation approach is recommended:

1. **Phase 1: Bottom Sheet Modal Refactoring**
   - Replace notification-based preset selection with modern sheet presentation
   - Create a prototype for the new approach that can be applied to other areas
   - Validate the approach with user testing

2. **Phase 2: Core State Management**
   - Implement @Observable models for identifiers, settings, and preferences
   - Gradually migrate from ObservableObject to @Observable where applicable
   - Ensure proper environment propagation through the view hierarchy

3. **Phase 3: Cache and Preloading System**
   - Create a unified cache state model with @Observable
   - Carefully refactor the interconnected caching notifications
   - Maintain critical recovery notifications until proven unnecessary

4. **Phase 4: Navigation and Trimming**
   - Update navigation to use modern NavigationStack approach
   - Refactor trim mode activation to use state instead of notifications

Remember to maintain backward compatibility with iOS 16 if needed, as @Observable is only available in iOS 17+. For iOS 16 support, consider using ObservableObject with more granular published properties as a fallback.