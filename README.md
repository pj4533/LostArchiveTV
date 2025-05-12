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
- Enhanced preloading system with visual indicators for improved user experience
- Prioritized video preloading that ensures seamless swiping transitions
- Robust caching system with automatic recovery mechanisms
- Shows metadata and descriptions for each video
- Video caching system for offline viewing and performance
- Smart time offset selection to show interesting parts of longer videos
- Collection-based video selection with preferred collection weighting and round-robin selection
- SQLite database for efficient identifier storage
- Video trimming functionality with timeline scrubbing
- Export trimmed video clips to Photos library
- Thumbnail generation for visual timeline navigation
- Optimized loading screen that displays content as soon as the first video is ready
- Favorites system for saving and revisiting interesting videos
- Centralized player management with improved code reuse
- Semantic search using natural language queries
- Similar videos recommendations for discovering related content
- Year-based filtering for search results
- Component-based UI architecture for consistent experience across features
- Retro-futuristic visual edge indicators for preloading and cached states

## How It Works

- Loads identifiers from a SQLite database with collection information
- Prioritizes preferred collections for better content selection
- Fetches metadata and streaming URLs via the Archive.org API
- Uses AVKit for high-performance video playback with centralized PlayerManager
- Implements Swift concurrency (async/await) for smooth operation
- Advanced preloading system with phased approach:
  - Phase 1: High-priority preloading for immediate swiping transitions
  - Phase 2: Background caching for upcoming content
- Visual indicators showing preloading status with dynamic blue-to-green transitions
- Enhanced buffer management for reliable video playback
- Maintains a video cache with failure recovery mechanisms
- Tracks viewing history for consistent bidirectional navigation
- Saves favorites with full metadata for easily accessing previously viewed content
- Stores favorites in newest-first order with comprehensive metadata
- Uses OpenAI for generating embeddings and Pinecone for vector search
- Offers semantic search for finding videos using natural language
- Provides similar video recommendations based on content similarity
- Comprehensive logging via OSLog for diagnostics
- Provides a trim interface with adjustable handles for selecting video segments
- Uses AVFoundation for trimming and exporting video clips
- Leverages inheritance with BaseVideoViewModel for code reuse
- Uses protocol-based approach for consistent player controls

## Requirements

- iOS 18.0+
- Xcode 16.0+
- Swift 5.9+
- API Keys (see Setup section)

## Setup

### API Keys

This project requires API keys for:

1. OpenAI - Used for semantic search embeddings
2. Pinecone - Used for vector search

Set them up using one of these methods:

#### Method 1: Environment Variables in Xcode Scheme (Recommended for developers)

1. Open Xcode and go to **Product > Scheme > Manage Schemes**
2. Duplicate the "LostArchiveTV" scheme and name it "LostArchiveTV-Dev" 
3. Select your new scheme and click "Edit..."
4. Go to the **Run** action and select the **Arguments** tab
5. Under **Environment Variables**, add:
   - `OPENAI_API_KEY` with your OpenAI API key
   - `PINECONE_API_KEY` with your Pinecone API key
   - `PINECONE_HOST` with your Pinecone host URL
6. Your personal scheme with API keys will be git-ignored (Xcode stores these in the xcuserdata directory)

#### Method 2: Environment Variables in CI/CD (For cloud builds)

For Xcode Cloud or other CI systems, set the environment variables:

- `OPENAI_API_KEY`
- `PINECONE_API_KEY`
- `PINECONE_HOST`

## Development

The app uses the Swift Testing framework for testing rather than XCTest. See the `docs/swifttesting_documentation.md` file for more information about this modern testing approach.

For detailed information about the video preloading and caching system, see the `docs/preloading_and_cacheing.md` file.

## License

This project is available under the MIT license. See the LICENSE file for more info.