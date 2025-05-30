# AVURLAsset Preloading Management in LostArchiveTV

This document explains how LostArchiveTV abstracts AVURLAsset usage to enable seamless video playback with bidirectional swiping, similar to TikTok's interface. It details the preloading strategy, memory management implications, and potential improvements.

## Overview

LostArchiveTV implements a sophisticated video preloading system that enables instant playback when swiping between videos. The key insight is that **preloading is primarily about preparing AVURLAssets** - the expensive network operations - rather than just creating AVPlayer instances.

## Core Architecture

### The CachedVideo Abstraction

The app's central abstraction is the `CachedVideo` struct, which encapsulates all necessary components for instant playback:

```swift
struct CachedVideo {
    let identifier: String          // Archive.org identifier
    let collection: String          // Collection name
    let metadata: ArchiveMetadata   // Full metadata including title, description
    let mp4File: ArchiveFile       // Selected video file with format info
    let videoURL: URL              // Direct URL to video file
    let asset: AVURLAsset          // Pre-loaded asset with video data
    let playerItem: AVPlayerItem   // Pre-configured player item
    let startPosition: Double      // Random start time within video
    let addedToFavoritesAt: Date?  // Optional timestamp for favorites
    let totalFiles: Int            // Number of video files in this item
}
```

The crucial elements are:
- **`asset: AVURLAsset`** - Contains the actual video data loaded from the network
- **`playerItem: AVPlayerItem`** - Pre-configured with buffer settings and ready to play

### Video Loading Pipeline

When loading a new video, the expensive operations occur at the AVURLAsset level:

```swift
// 1. Create asset with authentication headers (Network operation begins)
let asset = AVURLAsset(url: videoURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])

// 2. Load asset properties (Triggers actual network fetch)
try await asset.loadValues(forKeys: ["playable", "tracks", "duration"])

// 3. Create player item with format-specific buffer settings
let playerItem = AVPlayerItem(asset: asset)
playerItem.preferredForwardBufferDuration = bufferDuration // 15-60s based on format

// 4. Bundle into CachedVideo for storage
let cachedVideo = CachedVideo(
    identifier: identifier,
    asset: asset,
    playerItem: playerItem,
    // ... other properties
)
```

## Swipe System Implementation

### Forward Swiping (Next Video)

The forward swipe system involves complex preloading because it often requires loading entirely new content:

#### 1. Gesture Detection
```swift
// VideoGestureHandler detects upward swipe
if dragValue.translation.height < -100 || 
   dragValue.velocity.height < -500 {
    // Check if next video is ready
    if transitionManager.nextVideoReady {
        transitionManager.completeTransition(direction: .up)
    }
}
```

#### 2. Preload Coordination
The `TransitionPreloadManager` orchestrates next video preloading:

```swift
func preloadNextVideo() async {
    // Signal that transition preloading is starting
    cacheService.setPreloadingStarted()
    
    // Check history first
    if let nextVideo = provider.peekNextVideo() {
        // Reuse existing CachedVideo from history
        await setupPlayer(for: nextVideo)
    } else {
        // Load new video from cache or API
        let newVideo = await loadingService.loadRandomVideo()
        await setupPlayer(for: newVideo)
    }
    
    // Monitor buffer status
    await monitorBufferUntilReady()
    
    // Signal completion
    cacheService.setPreloadingComplete()
}
```

#### 3. Priority System
Transition preloading takes absolute priority:
- **Phase 1A**: Next video preload (blocks all caching)
- **Phase 1B**: Previous video preload (if needed)
- **Phase 2**: General cache filling (maintains 3-video buffer)

The `isPreloadingInProgress` flag ensures no cache operations interfere with transition preloading.

### Backward Swiping (Previous Video)

Backward swiping is remarkably simple because **the AVURLAsset already exists**:

#### 1. History Lookup
```swift
func completePreviousVideoTransition() {
    // Get previous video from history (non-destructive peek)
    guard let previousVideo = historyManager.peekPreviousVideo() else { return }
    
    // Move history index back
    historyManager.moveToPreviousVideo()
    
    // Transition to previous video
    transitionToPreviousVideo(previousVideo)
}
```

#### 2. Instant Player Creation
```swift
func setupPreviousPlayer(for cachedVideo: CachedVideo) {
    // Create fresh player item from existing asset (instant)
    let freshPlayerItem = AVPlayerItem(asset: cachedVideo.asset)
    
    // Create new player (instant)
    let player = AVPlayer(playerItem: freshPlayerItem)
    
    // Seek to saved position (fast, asset already loaded)
    await player.seek(to: CMTime(seconds: cachedVideo.startPosition))
    
    // Ready to play immediately
    prevVideoReady = true
}
```

**Key insight**: No network operations, no buffering wait. The expensive work (loading the AVURLAsset) was done when the video was first played.

## Why Backward Doesn't Need Preloading

The fundamental difference between forward and backward navigation:

### Forward Navigation Timeline:
1. User swipes up
2. Check if next video exists in history
3. If not, fetch new video metadata from API (200-500ms)
4. Create AVURLAsset and start loading (network operation)
5. Wait for initial buffering (1-5 seconds depending on connection)
6. Create AVPlayerItem and AVPlayer
7. Seek to start position
8. Ready to play

**Total time: 2-6 seconds**

### Backward Navigation Timeline:
1. User swipes down
2. Retrieve CachedVideo from history (instant, in-memory)
3. Create new AVPlayerItem from existing asset (1-5ms)
4. Create new AVPlayer (1-5ms)
5. Seek to saved position (10-50ms, data already buffered)
6. Ready to play

**Total time: 12-60 milliseconds**

## Memory Management: The Current Approach

### Infinite History Storage

The `VideoHistoryManager` maintains an unbounded array of `CachedVideo` objects:

```swift
class VideoHistoryManager {
    private var history: [CachedVideo] = []
    private var currentIndex: Int = -1
    
    func addVideo(_ video: CachedVideo) {
        // Truncate forward history if we've gone back
        if currentIndex < history.count - 1 {
            history = Array(history.prefix(currentIndex + 1))
        }
        
        // Add new video (no limit!)
        history.append(video)
        currentIndex = history.count - 1
    }
}
```

### Memory Implications

Each `CachedVideo` stores:
- **AVURLAsset**: Can hold 10-100MB of buffered video data
- **AVPlayerItem**: Additional playback state and buffers
- **Metadata**: Negligible compared to video data

After watching 50 videos:
- **Minimum**: 500MB (10MB per video)
- **Typical**: 1-2GB (20-40MB per video)
- **Maximum**: 5GB+ (100MB per video)

### Why This Works (Until It Doesn't)

Benefits:
- Instant backward navigation to any previously watched video
- No network re-fetching ever needed
- Smooth user experience
- Simple implementation

Drawbacks:
- Unbounded memory growth
- Eventual memory pressure and crashes
- No way to recover memory during active session
- iOS may kill app due to memory usage

## Potential Improvements

### 1. Bounded History with Smart Eviction

Implement a sliding window approach:

```swift
class ImprovedVideoHistoryManager {
    private let maxHistorySize = 20
    private var history: [CachedVideo] = []
    
    func addVideo(_ video: CachedVideo) {
        history.append(video)
        
        // Evict oldest videos beyond limit
        if history.count > maxHistorySize {
            let evicted = history.removeFirst()
            // Release the AVURLAsset
            evicted.asset.cancelLoading()
        }
    }
}
```

### 2. Lazy Asset Loading for Deep History

Store only metadata for older videos:

```swift
enum HistoryEntry {
    case loaded(CachedVideo)
    case metadata(VideoMetadata)
}

// Keep last 10 videos fully loaded
// Store only metadata for videos 11-50
// Discard videos beyond 50
```

### 3. Memory Pressure Response

React to memory warnings:

```swift
func handleMemoryWarning() {
    // Keep current ± 5 videos
    let keepRange = (currentIndex - 5)...(currentIndex + 5)
    
    for (index, video) in history.enumerated() {
        if !keepRange.contains(index) {
            // Convert to metadata-only
            history[index] = .metadata(video.extractMetadata())
        }
    }
}
```

### 4. Progressive Loading Strategy

Load assets on-demand with predictive preloading:

```swift
func preloadAroundIndex(_ index: Int) {
    let preloadRange = (index - 2)...(index + 2)
    
    for i in preloadRange {
        if case .metadata(let meta) = history[safe: i] {
            // Background load this asset
            Task { await loadAssetForMetadata(meta, at: i) }
        }
    }
}
```

## Conclusion

LostArchiveTV's approach to AVURLAsset management prioritizes user experience through aggressive preloading and infinite history retention. While this creates an incredibly smooth swiping experience, it comes at the cost of unbounded memory usage.

The key innovation is recognizing that **AVURLAssets are the expensive resource** - both in terms of loading time and memory usage. By keeping these assets in memory, the app eliminates network round-trips for backward navigation.

For developers implementing similar systems, consider:
1. Your typical session length and user behavior
2. Available device memory
3. Video file sizes and buffer requirements
4. Whether instant backward navigation to any previous video is truly necessary

A bounded history with smart eviction (keeping perhaps the last 10-20 videos fully loaded) would likely provide 99% of the user experience benefits while avoiding the memory growth issues. The current implementation works well for short sessions but will eventually hit memory limits in extended use.