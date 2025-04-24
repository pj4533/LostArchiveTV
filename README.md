# LostArchiveTV

A TikTok-style iOS video player for exploring videos from the Internet Archive with video trimming capabilities and bidirectional swiping.

![LostArchiveTV Screenshot](lostarchivetv.gif)

# [Join the TestFlight](https://testflight.apple.com/join/5u5qyTWh)
## About

LostArchiveTV lets you discover historical films, educational videos, and other public domain content from [Archive.org](https://archive.org) in a modern, swipeable interface. Each swipe presents a new randomly selected video clip from the Archive's vast collection. You can also trim and save segments of videos to your Photos library, and swipe down to revisit previously viewed videos.

## Features

- TikTok-style swipeable video interface with bidirectional navigation
- Displays random clips from Archive.org's collection
- Bidirectional swiping with history tracking for navigating forward and backward
- Preloads videos for smooth playback experience
- Shows metadata and descriptions for each video
- Video caching system for offline viewing and performance
- Smart time offset selection to show interesting parts of longer videos
- Collection-based video selection with preferred collection weighting
- SQLite database for efficient identifier storage
- Video trimming functionality with timeline scrubbing
- Export trimmed video clips to Photos library
- Thumbnail generation for visual timeline navigation
- Optimized loading screen that displays content as soon as the first video is ready

## How It Works

- Loads identifiers from a SQLite database with collection information
- Prioritizes preferred collections for better content selection
- Fetches metadata and streaming URLs via the Archive.org API
- Uses AVKit for high-performance video playback
- Implements Swift concurrency (async/await) for smooth operation
- Preloads upcoming videos in the background
- Maintains a video cache for optimal performance
- Tracks viewing history for consistent bidirectional navigation
- Comprehensive logging via OSLog for diagnostics
- Provides a trim interface with adjustable handles for selecting video segments
- Uses AVFoundation for trimming and exporting video clips

## Requirements

- iOS 18.0+
- Xcode 16.0+
- Swift 5.9+

## Development

The app uses the Swift Testing framework for testing rather than XCTest. See the `docs/swifttesting_documentation.md` file for more information about this modern testing approach.

For detailed information about the video preloading and caching system, see the `docs/preloading_and_cacheing.md` file.

## License

This project is available under the MIT license. See the LICENSE file for more info.