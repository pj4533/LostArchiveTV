# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
- LostArchiveTV is an app that plays random videos from the Internet Archive
- Uses the Archive.org API to fetch metadata and stream videos
- Implements a TikTok-style video player with random clip selection
- Features bidirectional swiping with history tracking for navigating forward and backward
- Features video preloading and caching for smoother playback experience
- Uses SQLite database for storing video identifiers organized by collections
- Prioritizes content from preferred collections for better user experience
- Provides video trimming functionality to save clips to Photos library
- Optimized loading experience that shows content as soon as the first video is ready

## Build and Test Commands
- Build app: `xcodebuild -scheme LostArchiveTV -destination 'platform=iOS Simulator,name=iPhone 16' build`
- Build and check for errors: `xcodebuild -scheme LostArchiveTV -destination 'platform=iOS Simulator,name=iPhone 16' build | grep -A 2 "error:" || echo "Build successful - no errors found"`
- Run tests: `xcodebuild -scheme LostArchiveTV -destination 'platform=iOS Simulator,name=iPhone 16' test`
- Run single test: `xcodebuild -scheme LostArchiveTV -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:LostArchiveTVTests/[TestName]`
- Verify build after making changes: Run the build command to ensure there are no errors

## Project Structure
- Organized into separate Models, Views, ViewModels, and Services directories
- Models in `Models/` directory: ArchiveIdentifier, ArchiveMetadata, ArchiveFile, ItemMetadata, CachedVideo, ArchiveCollection
- Views in `Views/` directory: ContentView, VideoPlayerContent, LoadingView, ErrorView, VideoInfoOverlay, SwipeableVideoView, VideoTrimView, TimelineView, TrimHandle, TrimDownloadView
- Services in `Services/` directory: ArchiveService, VideoCacheManager, VideoPlaybackManager, VideoTrimManager, VideoSaveManager, VideoExportService, PreloadService, LoggingService, VideoLoadingService, VideoDownloadService, VideoTransitionManager, TimelineManager, AudioSessionManager
- ViewModels: VideoPlayerViewModel.swift and VideoTrimViewModel.swift (both use MainActor for UI updates)
- App entry point in `LostArchiveTVApp.swift`
- Video identifiers stored in `identifiers.sqlite` database with collections table and individual collection tables
- You NEVER have to alter the Xcode project file to add new files - the project uses folder references that automatically include any new files

## Feature: Bidirectional Swiping
- Supports swiping up for next (new) videos and down for previous videos
- Maintains a history of viewed videos for consistent navigation
- VideoTransitionManager handles the swiping logic and history tracking
- Properly manages history when navigating backward then forward again
- Preserves video positions when returning to previously viewed content

## Feature: Video Preloading and Caching
- PreloadService manages the preloading of videos for smooth playback
- VideoCacheManager handles the caching of videos for improved performance
- VideoLoadingService coordinates the loading of videos from the API
- Maintains a small cache of preloaded videos (typically 3 videos at a time)
- Continuously preloads new videos as others are consumed from the cache
- See `docs/preloading_and_cacheing.md` for detailed documentation

## Feature: Video Trimming
- VideoTrimView provides the UI for trimming videos with a timeline and handles
- TimelineView displays video thumbnails and trim handles for visual reference
- VideoTrimViewModel coordinates the trim interface, playback, and saving functions
- VideoTrimManager handles the actual video extraction and processing
- VideoExportService manages exporting of trimmed videos to Photos library
- TrimDownloadView shows the download progress when preparing videos for trimming
- Auto-hiding play/pause button provides better user experience during trimming
- Videos can be trimmed to custom lengths with visual timeline for reference

## Testing Approach
- Uses Swift Testing framework (not XCTest) for unit tests
- Tests are organized by service functionality in separate test files
- Each test focuses on a specific functionality aspect with clear Arrange/Act/Assert structure
- No mock classes are used; tests use the actual implementations
- Test files follow the naming convention of [ServiceName]Tests.swift

## Database Structure
- SQLite database with a `collections` table listing all available collections and their preferred status
- Each collection has its own table containing identifiers for that collection
- Database is bundled with the app and accessed via SQLite3 C API

## Code Style Guidelines
- Use SwiftUI for all UI components
- Use async/await for asynchronous operations (NEVER use Combine)
- Use Codable for data models to support both encoding and decoding
- Use computed properties for derived values
- Use MainActor for UI-related view models
- Group related functionality using extensions
- Use optional chaining for handling nullable values
- Explicitly handle errors with try/catch
- Keep functions small and focused on a single responsibility
- Leverage OSLog for structured logging across different categories (network, metadata, caching, etc.)
- Use descriptive variable names following Swift conventions (camelCase)
- Implement robust error handling and recovery