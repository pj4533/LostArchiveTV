# LostArchiveTV

A TikTok-style iOS video player for exploring films from the Internet Archive.

![LostArchiveTV Screenshot](lost_archive_tv.png)

## About

LostArchiveTV lets you discover historical films, educational videos, and other public domain content from [Archive.org](https://archive.org) in a modern, swipeable interface. Each swipe presents a new randomly selected video clip from the Archive's vast collection.

## Features

- TikTok-style swipeable video interface
- Displays random clips from Archive.org's collection
- Preloads videos for smooth playback experience
- Shows metadata and descriptions for each video
- Video caching system for offline viewing and performance
- Smart time offset selection to show interesting parts of longer videos

## How It Works

- Loads a curated list of Archive.org identifiers
- Fetches metadata and streaming URLs via the Archive.org API
- Uses AVKit for high-performance video playback
- Implements Swift concurrency (async/await) for smooth operation
- Preloads upcoming videos in the background
- Maintains a video cache for optimal performance

## Requirements

- iOS 18.0+
- Xcode 16.0+
- Swift 5.9+

## License

This project is available under the MIT license. See the LICENSE file for more info.