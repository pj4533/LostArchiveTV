# Video Preloading and Caching in LostArchiveTV

This document provides a high-level overview of how video loading, caching, and playback work in LostArchiveTV, with a focus on the user experience during swiping interactions. The system has been significantly enhanced to improve reliability and performance.

## Video Caching Architecture

LostArchiveTV uses a sophisticated caching system to ensure smooth playback when users browse through videos. The system has three main components:

1. **VideoCacheService**: Coordinates the overall caching strategy
2. **VideoCacheManager**: Manages the actual cache storage and status tracking
3. **TransitionPreloadManager**: Handles the preparation of videos for swiping transitions

The caching system:

- Maintains a small cache of preloaded videos (typically 3 videos at a time)
- Stores both the video assets and their associated metadata
- Uses a first-in, first-out (FIFO) approach to manage cache size
- Prepares videos with optimized settings for immediate playback
- Provides visual feedback on preloading status through UI indicators

Videos in the cache are fully prepared for playback, including:

- Pre-buffered content to minimize loading time
- Pre-configured playback parameters
- Random start positions for variety in content viewing
- Validated buffer status using `loadedTimeRanges` checks

## Phased Preloading Strategy

To provide a seamless swiping experience, LostArchiveTV uses a phased approach to video preloading:

### Phase 1: Priority Preloading
- Focused on immediate swiping transitions
- Takes precedence over all other caching operations
- Handled by the TransitionPreloadManager (refactored into extensions)
- Initiates a hard block on general caching during transitions
- Provides visual feedback through RetroEdgePreloadIndicator

### Phase 2: Background Caching
- Fills the remainder of the cache after transition preloading is complete
- Operates as a background task with lower priority
- Can be gracefully interrupted when transition preloading is needed
- Uses chunked operations with checkpoint breaks for clean interruption
- Automatically recovers from stalled states

The system follows this sequence:

1. **Initial Load**: When the app starts, it immediately begins preloading the first video
2. **Transition Preparation**: Once the first video is playing, prepares next/previous videos for swipe transitions
3. **Background Caching**: After transition preloading completes, fills the remaining cache slots
4. **Continuous Monitoring**: Constantly checks cache status and restarts caching as needed
5. **Recovery Mechanisms**: Automatically detects and resolves stalled caching operations

This strategy ensures that a video is always ready to play when the user swipes, regardless of their internet connection speed at the moment of swiping.

## Visual Feedback System

The app provides visual feedback on the caching process:

- **RetroEdgePreloadIndicator**: Displays a glowing edge border during preloading
- **Color Transitions**: Shifts from blue (preloading) to green (preloaded) with a dramatic animation
- **Corner Indicator**: Shows a green dot when preloading is complete
- **ShimmerTextEffect**: Adds a shimmer animation to preloaded video notification texts

These visual elements help users understand when the next video is ready for swiping.

## Swiping Direction and Video Navigation

LostArchiveTV supports bidirectional swiping to navigate through content:

### Swiping Up (Next Video)
- Transitions to a new random video from the cache
- Preloads a new video to replace the one just viewed
- Updates the history to include the new video at the current position
- If returning to a previously viewed video in history, retrieves it from history
- Uses high-priority preloading to ensure next videos are always ready

### Swiping Down (Previous Video)
- Returns to the previously viewed video in history
- Maintains the position in the video where the user left off
- Preserves the user's viewing history for consistent navigation
- Updates the preloading queue to accommodate the backward navigation
- Uses the same priority mechanism as forward swiping

## History Tracking vs. Video Caching

It's important to understand the distinction between history tracking and video caching:

### History Tracking
- Maintains a sequential record of videos the user has viewed
- Allows users to navigate backward and forward through their viewing history
- Records metadata and viewing positions for consistent experience
- Manages truncation of forward history when navigating backward then forward again
- Fixed to properly maintain history during complex navigation patterns

### Video Caching
- Temporarily stores video data for performance optimization
- Focuses on reducing load times and buffering
- Manages a limited set of ready-to-play videos
- Operates independently of the viewing history system
- Now uses a priority-based approach that ensures smooth transitions

## Performance Optimizations and Reliability Enhancements

Several techniques ensure optimal performance and reliability:

- **Priority-Based Caching**: Ensures transition preloading takes precedence over general caching
- **State Management**: Uses explicit state flags to coordinate between different caching operations
- **Chunked Caching Operations**: Breaks caching into smaller steps with checkpoint breaks for clean interruption
- **Smart Buffer Management**: Monitors and manages video buffering using loadedTimeRanges checks
- **Memory Efficiency**: Limits the cache size to balance performance with memory usage
- **Concurrent Preloading**: Loads videos in the background without affecting the current playback
- **Resource Cleanup**: Properly disposes of unused video assets to prevent memory leaks
- **Recovery Mechanisms**: Automatically detects and resolves stalled caching operations
- **Timeout Handling**: Prevents operations from hanging indefinitely
- **Comprehensive Logging**: Provides detailed logs for debugging and performance monitoring

## User Experience Benefits

These systems work together to create a smooth user experience:

- **Instant Playback**: Videos start playing immediately when swiped to
- **Consistent Navigation**: Users can reliably navigate their viewing history
- **Seamless Transitions**: Smooth animations between videos hide loading processes
- **Visual Feedback**: Dynamic indicators show when the next video is ready
- **Offline Resilience**: Cached videos can be viewed even with intermittent connectivity
- **Collection Preferences**: Content from preferred collections appears more frequently
- **Reliable Performance**: Enhanced robustness prevents freezes or stuttering
- **Auto Recovery**: System automatically recovers from interrupted operations
- **Dramatic Transitions**: Blue-to-green animations indicate successful preloading

## Implementation Details

Key implementation components include:

- **VideoCacheService**: Coordinates caching priorities and manages the caching lifecycle
- **TransitionPreloadManager**: Split into multiple extension files for better organization
- **RetroEdgePreloadIndicator**: Provides visual feedback on preloading status
- **PreloadingIndicatorManager**: Coordinates the display of preloading indicators
- **VideoCacheManager+CacheStatus**: Tracks the readiness status of cached videos
- **ShimmerTextEffect**: Adds dynamic text animations for preloaded notifications

The system uses a combination of SwiftUI animations, OSLog-based logging, and actor-based concurrency to ensure robust performance across different network conditions and device capabilities.

