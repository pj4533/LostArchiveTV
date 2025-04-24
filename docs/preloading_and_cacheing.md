# Video Preloading and Caching in LostArchiveTV

This document provides a high-level overview of how video loading, caching, and playback work in LostArchiveTV, with a focus on the user experience during swiping interactions.

## Video Caching Overview

LostArchiveTV uses a sophisticated caching system to ensure smooth playback when users browse through videos. The caching system:

- Maintains a small cache of preloaded videos (typically 3 videos at a time)
- Stores both the video assets and their associated metadata
- Uses a first-in, first-out (FIFO) approach to manage cache size
- Prepares videos with optimized settings for immediate playback

Videos in the cache are fully prepared for playback, including:

- Pre-buffered content to minimize loading time
- Pre-configured playback parameters
- Random start positions for variety in content viewing

## Preloading Strategy

To provide a seamless swiping experience, LostArchiveTV proactively preloads videos:

1. **Initial Load**: When the app starts, it immediately begins preloading videos into the cache
2. **Continuous Preloading**: As videos are consumed from the cache, new ones are automatically preloaded
3. **Bidirectional Preparation**: The app prepares videos for both swiping up (next) and down (previous)
4. **Collection Preferences**: Preloading respects the user's collection preferences, prioritizing content from preferred collections

This strategy ensures that a video is always ready to play when the user swipes, regardless of their internet connection speed at the moment of swiping.

## Swiping Direction and Video Navigation

LostArchiveTV supports bidirectional swiping to navigate through content:

### Swiping Up (Next Video)
- Transitions to a new random video from the cache
- Preloads a new video to replace the one just viewed
- Updates the history to include the new video at the current position
- If returning to a previously viewed video in history, retrieves it from history

### Swiping Down (Previous Video)
- Returns to the previously viewed video in history
- Maintains the position in the video where the user left off
- Preserves the user's viewing history for consistent navigation
- Updates the preloading queue to accommodate the backward navigation

## History Tracking vs. Video Caching

It's important to understand the distinction between history tracking and video caching:

### History Tracking
- Maintains a sequential record of videos the user has viewed
- Allows users to navigate backward and forward through their viewing history
- Records metadata and viewing positions for consistent experience
- Manages truncation of forward history when navigating backward then forward again

### Video Caching
- Temporarily stores video data for performance optimization
- Focuses on reducing load times and buffering
- Manages a limited set of ready-to-play videos
- Operates independently of the viewing history system

## Performance Optimizations

Several techniques ensure optimal performance:

- **Smart Buffer Management**: Monitors and manages video buffering to prevent playback interruptions
- **Memory Efficiency**: Limits the cache size to balance performance with memory usage
- **Concurrent Preloading**: Loads videos in the background without affecting the current playback
- **Resource Cleanup**: Properly disposes of unused video assets to prevent memory leaks

## User Experience Benefits

These systems work together to create a smooth user experience:

- **Instant Playback**: Videos start playing immediately when swiped to
- **Consistent Navigation**: Users can reliably navigate their viewing history
- **Seamless Transitions**: Smooth animations between videos hide loading processes
- **Offline Resilience**: Cached videos can be viewed even with intermittent connectivity
- **Collection Preferences**: Content from preferred collections appears more frequently

