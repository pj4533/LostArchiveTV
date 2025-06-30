# App Launch Video Loading Architecture

## Overview

This document provides a comprehensive analysis of how LostArchiveTV loads the first two videos during app launch. The loading process for these initial videos differs significantly from subsequent video loading and involves complex interactions between multiple systems.

## Table of Contents

1. [App Launch Sequence](#app-launch-sequence)
2. [First Video Loading](#first-video-loading)
3. [Second Video Loading](#second-video-loading)
4. [Component Interactions](#component-interactions)
5. [Identified Issues](#identified-issues)
6. [Technical Deep Dive](#technical-deep-dive)

## App Launch Sequence

### 1. Initial Bootstrap (`LostArchiveTVApp.swift:12-76`)

The app initialization follows this sequence:

1. **App Entry** - `@main struct LostArchiveTVApp`
2. **Environment Setup** - Loads API keys from `EnvironmentService`
3. **Analytics Init** - Configures Mixpanel with anonymous user ID
4. **View Creation** - Creates `ContentView` which initializes all view models

### 2. View Model Hierarchy Creation (`ContentView.swift:24-62`)

ContentView creates the following in order:
- Shared services (FavoritesManager, VideoLoadingService, SearchManager)
- FavoritesViewModel
- SearchViewModel
- **VideoPlayerViewModel** (the main player - this triggers video loading)
- FavoritesFeedViewModel
- SearchFeedViewModel

### 3. Initial UI State

- Shows `LoadingView` while `VideoPlayerViewModel.isInitializing = true`
- Switches to `SwipeablePlayerView` once first video loads

## First Video Loading

The first video uses a **fast-path direct loading mechanism** that bypasses the caching system entirely:

### Loading Flow (`VideoPlayerViewModel.swift:70-109`)

```
1. VideoPlayerViewModel.init()
   ↓
2. Sets isInitializing = true (shows loading screen)
   ↓
3. Async Task: loadIdentifiers()
   ↓
4. loadFirstVideoDirectly() - BYPASSES CACHE
   ↓
5. VideoLoadingService.loadFreshRandomVideo()
   ↓
6. Creates AVPlayer directly
   ↓
7. Starts playback immediately
   ↓
8. Sets isInitializing = false (hides loading screen)
   ↓
9. Signals cacheService.setFirstVideoReady()
   ↓
10. Triggers background caching
```

### Key Characteristics

- **No preloading** - Video loads directly from Archive.org API
- **No caching** - Bypasses VideoCacheService completely
- **No preload indicators** - Rainbow animation triggered manually after load
- **Immediate playback** - Starts playing as soon as asset is ready
- **Fast startup** - Optimized for minimal time-to-first-frame

### Code References

- Direct load method: `VideoPlayerViewModel+VideoLoading.swift:54-140`
- Fresh video load: `VideoLoadingService.swift:233-382`
- First video ready signal: `VideoCacheService.swift:128`

## Second Video Loading

The second video is the **first video to use the preloading system** and has unique characteristics:

### Loading Flow

```
1. First video playing
   ↓
2. ensureVideosAreCached() starts
   ↓
3. PreloadingIndicatorManager.setPreloading() (manual trigger)
   ↓
4. TransitionPreloadManager.preloadNextVideo()
   ↓
5. Checks history (empty - no next video)
   ↓
6. VideoLoadingService.loadRandomVideo()
   ↓
7. Checks cache (likely empty)
   ↓
8. Falls back to loadFreshRandomVideo()
   ↓
9. Creates nextPlayer with video
   ↓
10. Monitors buffer via BufferingMonitor
   ↓
11. When buffer ready → indicator turns green
   ↓
12. Sets nextVideoReady = true
```

### Key Differences from Subsequent Videos

| Aspect | Second Video | 3rd+ Videos |
|--------|--------------|-------------|
| Cache State | Empty or 1 video | 5-10 videos cached |
| Load Source | Fresh from API | From cache |
| Preload Trigger | Manual after first video | Automatic on transition |
| Buffer Time | Longer (no cache) | Faster (cached) |
| History | None | Previous videos available |

### Code References

- Preload trigger: `VideoPlayerViewModel+VideoLoading.swift:241-248`
- Next video preload: `TransitionPreloadManager+NextVideo.swift:24-123`
- Cache check: `VideoLoadingService.swift:209`

## Component Interactions

### 1. VideoCacheService

- **First Video**: Completely bypassed
- **Second Video**: Cache likely empty, blocks during preload
- **Role**: Maintains background cache of 5-10 videos
- **Key Flag**: `isFirstVideoReady` prevents caching until first video plays

### 2. PreloadingIndicatorManager

- **Singleton**: `PreloadingIndicatorManager.shared`
- **Monitors**: Polls BufferingMonitor every 500ms
- **States**: `.preloading` (rainbow) → `.preloaded` (green)
- **Issue**: Never returns to `.notPreloading` state

### 3. RetroEdgePreloadIndicator

- **Visual States**:
  - Rainbow animation during preloading
  - Green pulse when buffer ready
  - Never goes transparent/black
- **Timing**: Can show green before swipes enabled

### 4. BufferingMonitor

- **Three Instances**: current, next, previous
- **Buffer Tracking**: Monitors AVPlayerItem loaded time ranges
- **Ready States**: sufficient (10s), good (20s), excellent (30s)
- **Stabilization**: Requires 3 consistent readings

### 5. VideoTransitionManager

- **Swipe Control**: Checks `nextVideoReady` flag
- **Preload Management**: Coordinates with TransitionPreloadManager
- **History**: Maintains video navigation history

## Identified Issues

### 1. Race Condition: Green Indicator vs. Swipe Enablement

**Problem**: Indicator shows green before swipes are actually enabled

**Cause**: 
- Indicator based on buffer state alone
- Swipe enablement requires additional player readiness checks

**Impact**: User confusion when green indicator appears but swipe is blocked

### 2. First Video Preload Indicator

**Problem**: Manual trigger causes timing mismatch

**Details**:
- First video triggers indicator after loading (`VideoPlayerViewModel+VideoLoading.swift:131`)
- Subsequent videos trigger during transition
- Creates inconsistent visual feedback

### 3. Cache Empty State

**Problem**: Second video often loads from network despite caching system

**Cause**:
- Cache hasn't had time to fill
- First video bypasses cache entirely
- Background caching just starting

### 4. Buffer Monitor Connection Timing

**Problem**: Monitor connects after player creation

**Impact**: May miss early buffering events

**Location**: `TransitionPreloadManager+NextVideo.swift:78-84`

### 5. Perpetual Preloading State

**Problem**: `notifyCachingCompleted()` never called

**Impact**: System stays in "preloading" state indefinitely

## Technical Deep Dive

### Video Loading Optimization

The first video uses these optimizations (`VideoLoadingService.swift:273-347`):
- Format-specific AVURLAsset settings
- Preloaded asset keys: ["playable", "duration", "tracks"]
- Custom buffer configuration per format (h.264 IA, h.264, MPEG4)

### Buffer State Calculation

```swift
// BufferState.swift:36-53
static func from(seconds: Double) -> BufferState {
    switch seconds {
    case 30...: return .excellent
    case 20...: return .good  
    case 10...: return .sufficient
    case 5...: return .low
    default: return .minimal
    }
}
```

### Preload Blocking Mechanism

```swift
// VideoCacheService+StateManagement.swift:65-71
func startPreloading() {
    isPreloadingInProgress = true
    preloadingStatusSubject.send(.started)
}
```

### Critical Timeline

| Time | Event | Component |
|------|-------|-----------|
| T+0ms | App launch | LostArchiveTVApp |
| T+100ms | View models created | ContentView |
| T+200ms | Start loading identifiers | VideoPlayerViewModel |
| T+500ms | Identifiers loaded | DatabaseService |
| T+600ms | Start loading first video | VideoLoadingService |
| T+1000ms | First video ready | AVPlayer |
| T+1100ms | Hide loading screen | VideoPlayerViewModel |
| T+1200ms | Start background caching | VideoCacheService |
| T+1300ms | Start preloading second video | TransitionPreloadManager |
| T+3000ms | Second video buffer ready | BufferingMonitor |
| T+3100ms | Indicator turns green | RetroEdgePreloadIndicator |

## Recommendations

1. **Synchronize Green Indicator**: Tie indicator state to actual swipe readiness, not just buffer state
2. **Preload First Video**: Consider preloading while showing splash screen
3. **Cache Warmup**: Pre-fill cache during identifier loading
4. **Consistent Triggers**: Use same preload trigger mechanism for all videos
5. **Complete Notifications**: Implement proper completion notifications for cache operations