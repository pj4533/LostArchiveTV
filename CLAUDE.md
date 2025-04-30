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
- Includes semantic search capabilities to find relevant videos
- Offers similar videos recommendation feature
- Provides favorites system for saving and revisiting interesting videos

## Build and Test Commands
- Build app: `xcodebuild -scheme LostArchiveTV -destination 'platform=iOS Simulator,name=iPhone 16' build`
- Build and check for errors: `xcodebuild -scheme LostArchiveTV -destination 'platform=iOS Simulator,name=iPhone 16' build | grep -A 2 "error:" || echo "Build successful - no errors found"`
- Run tests: `xcodebuild -scheme LostArchiveTV -destination 'platform=iOS Simulator,name=iPhone 16' test`
- Run single test: `xcodebuild -scheme LostArchiveTV -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:LostArchiveTVTests/[TestName]`
- Verify build after making changes: Run the build command to ensure there are no errors

## Project Structure
- Organized into separate Models, Views, ViewModels, and Services directories
- Models in `Models/` directory: ArchiveIdentifier, ArchiveMetadata, ArchiveFile, ItemMetadata, CachedVideo, ArchiveCollection, CollectionPreferences, CollectionConfigViewModel, SearchResult, PineconeMatch, FeedItem
- Views in `Views/` directory: ContentView, VideoPlayerContent, LoadingView, ErrorView, VideoInfoOverlay, SwipeableVideoView, VideoTrimView, TimelineView, TrimHandle, TrimDownloadView, SearchView, SearchFeedView, FavoritesView, FavoritesFeedView, SimilarView
- Services in `Services/` directory: ArchiveService, VideoCacheManager, VideoPlaybackManager, PlayerManager, VideoTrimManager, VideoSaveManager, VideoExportService, PreloadService, LoggingService, VideoLoadingService, VideoDownloadService, VideoTransitionManager, TimelineManager, AudioSessionManager, FavoritesManager, SearchManager, OpenAIService, PineconeService, EnvironmentService
- ViewModels: BaseVideoViewModel, BaseFeedViewModel, VideoPlayerViewModel, VideoTrimViewModel, FavoritesViewModel, SearchViewModel, SearchFeedViewModel, FavoritesFeedViewModel, VideoDownloadViewModel (all use MainActor for UI updates)
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
- TransitionPreloadManager ensures smooth transitions between video views
- VideoDownloadService handles the background downloading of full videos
- VideoDownloadViewModel provides UI feedback during download operations
- See `docs/preloading_and_cacheing.md` for detailed documentation

## Feature: Centralized Player Management
- PlayerManager provides a single source of truth for player functionality
- Handles audio session configuration via AudioSessionManager
- Manages AVPlayer lifecycle, time observation, and playback status
- Improves code reuse through service-based architecture
- VideoPlaybackManager acts as a facade that delegates to PlayerManager
- BaseVideoViewModel provides shared player functionality for view models
- VideoControlProvider protocol and extensions standardize playback controls
- Component-based button architecture for player controls (PlayerButtonPanel)
- Consistent player UI across main feed, search results, and favorites

## Feature: Video Trimming
- VideoTrimView provides the UI for trimming videos with a timeline and handles
- TimelineView displays video thumbnails and trim handles for visual reference
- VideoTrimViewModel coordinates the trim interface, playback, and saving functions
- VideoTrimManager handles the actual video extraction and processing
- VideoExportService manages exporting of trimmed videos to Photos library
- TrimDownloadView shows the download progress when preparing videos for trimming
- Auto-hiding play/pause button provides better user experience during trimming
- Videos can be trimmed to custom lengths with visual timeline for reference

## Feature: Favorites
- Allows users to save videos they want to revisit later
- FavoritesManager handles saving and retrieving favorites data stored in UserDefaults
- Favorites include comprehensive metadata (identifier, collection, title, description, URL, playback position, timestamp)
- New favorites are inserted at the beginning of the list for newest-first ordering
- FavoritesViewModel extends BaseVideoViewModel for consistent player experience
- FavoritesFeedViewModel extends BaseFeedViewModel for feed-style browsing
- FavoritesView displays saved videos in a custom interface with pagination support
- Integrates with the video player components for a consistent UI
- Favorites can be toggled from both main video player and search results

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

## Feature: Semantic Search
- Allows users to find videos using natural language queries
- OpenAIService generates embeddings for semantic search 
- PineconeService performs vector similarity search using the embeddings
- SearchManager coordinates between services and view models
- SearchView provides the interface for entering search criteria
- SearchFeedView displays results in a swipeable feed like the main player
- Support for filtering results by year range
- Detailed implementation documentation in `docs/pinecone_search.md`

## Feature: Similar Videos
- Shows videos with similar content to the currently playing video
- Uses the same vector search technology as the main search feature
- SimilarView displays the related videos in a dedicated interface
- SimilarButton allows easy access to this feature from the player
- PineconeService+Similar extension handles finding semantically similar content

## Code Style Guidelines
- Use SwiftUI for all UI components
- Use async/await for asynchronous operations (NEVER use Combine)
- Use Codable for data models to support both encoding and decoding
- Use computed properties for derived values
- Use MainActor for UI-related view models
- Use inheritance with BaseVideoViewModel for shared video functionality
- Group related functionality using extensions
- Use optional chaining for handling nullable values
- Explicitly handle errors with try/catch
- Keep functions small and focused on a single responsibility
- Follow the DRY principle with centralized services like PlayerManager
- Leverage OSLog for structured logging across different categories (network, metadata, caching, etc.)
- Use descriptive variable names following Swift conventions (camelCase)
- Implement robust error handling and recovery
- Use protocol-based design for flexible component interfaces
- Prefer facade services that delegate to specialized managers