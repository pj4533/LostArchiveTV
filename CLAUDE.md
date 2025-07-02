# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
LostArchiveTV is a tvOS app that plays random videos from the Internet Archive with a TikTok-style swipeable interface.

### Core Features
- Random video playback from Archive.org collections
- Bidirectional swiping (up for next, down for previous) with history tracking
- Advanced preloading and caching for smooth transitions
- Video trimming and export to Photos library
- Semantic search using OpenAI embeddings and Pinecone vector search
- Favorites system for saving videos
- Similar videos recommendations
- Analytics integration with Mixpanel

## Critical Build Commands

**IMPORTANT: To save context window space, ALWAYS use the Task agent to run builds and tests. The agent should report back only the specific errors or warnings that occurred.**

```bash
# Build and check for errors (ALWAYS run after making changes)
# NOTE: Use -derivedDataPath .build to store build artifacts locally and avoid conflicts
xcodebuild -scheme LostArchiveTV -destination 'platform=iOS Simulator,name=iPhone 16,arch=arm64' -derivedDataPath .build build | xcbeautify

# Run tests (ALWAYS run ALL tests - never try to run individual tests)
xcodebuild -scheme LostArchiveTV -destination 'platform=iOS Simulator,name=iPhone 16,arch=arm64' -derivedDataPath .build test | xcbeautify
```

### Build Process Guidelines
1. **Use Task agent for builds**: Spawn a Task agent to run the build command and report back only errors/warnings
2. **Fix errors with agents**: When fixing build errors or warnings, spawn a Task agent to handle the fixes
3. **Keep context clean**: This approach prevents build logs from overwhelming the primary context window

## Project Architecture

### Directory Structure
- `Models/` - Data models and business logic entities
- `Views/` - SwiftUI views and UI components
- `Views/Components/` - Reusable UI components
- `ViewModels/` - View models using @MainActor for UI updates
- `Services/` - Business logic and external integrations
- `Protocols/` - Protocol definitions for architecture patterns

### Key Architectural Patterns
- **MVVM Architecture**: Views, ViewModels (with @MainActor), and Services
- **Base Classes**: BaseVideoViewModel and BaseFeedViewModel for shared functionality
- **Protocol-Based Design**: VideoProvider, VideoControlProvider, FeedItem protocols
- **Service Layer**: Centralized services for player, cache, and API management
- **Dependency Injection**: SharedViewModelProvider for view model management

### Important Files
- `LostArchiveTVApp.swift` - App entry point
- `identifiers.sqlite` - SQLite database with video collections
- `SecretsTemplate.swift` - Template for API keys (create Secrets.swift locally)
- **NEVER modify the .xcodeproj file** - Uses folder references for automatic file inclusion

## Key Services and Components

### Video Management
- **VideoTransitionManager**: Handles bidirectional swiping and history
- **VideoCacheService**: Priority-based video preloading system
- **VideoCacheManager**: Tracks cache status and manages preloaded videos
- **VideoLoadingService**: Coordinates API loading and caching
- **PlayerManager**: Centralized AVPlayer lifecycle management
- **VideoPlaybackManager**: Facade for player operations

### Data and Search
- **ArchiveService**: Interface to Archive.org API
- **OpenAIService**: Generates embeddings for semantic search
- **PineconeService**: Vector similarity search
- **FavoritesManager**: Persists favorite videos in UserDefaults
- **DatabaseService**: SQLite interface for video identifiers

### UI Components
- **SwipeableVideoView**: Main video player with gesture handling
- **VideoTrimView**: Timeline-based video trimming interface
- **SearchFeedView**: Swipeable feed for search results
- **RetroEdgePreloadIndicator**: Visual preloading status

## Testing Requirements
- **Use Swift Testing framework** (not XCTest)
- **No mock objects** - use actual implementations
- Follow `[ServiceName]Tests.swift` naming convention
- Structure tests with clear Arrange/Act/Assert pattern

## Code Style Rules
1. **Always use SwiftUI** for UI components
2. **Always use @MainActor** for ViewModels
3. **Always use Codable** for data models
4. **Always handle errors explicitly** with try/catch
5. **Always run build command** after making changes
6. **Never modify .xcodeproj file**
7. **Never use force unwrapping** - use optional chaining
8. **Use OSLog** for structured logging
9. **Follow Swift naming conventions** (camelCase)
10. **Extend base classes** (BaseVideoViewModel, BaseFeedViewModel) for consistency

## Environment Setup
- API keys go in `Secrets.swift` (copy from `SecretsTemplate.swift`)
- Mixpanel token uses `MIXPANEL_TOKEN` environment variable
- See `docs/` for detailed feature documentation

## Documentation References

### Swift Language Guides
- **docs/modern-swift.md** - Modern Swift patterns and best practices
- **docs/swift-concurrency.md** - Swift concurrency (async/await, actors, tasks)
- **docs/swift6-migration.mdc** - Swift 6 migration guide and data race safety
- **docs/swiftui.md** - SwiftUI patterns and common solutions

### Framework-Specific Guides
- **docs/swift-argument-parser.mdc** - Command-line argument parsing in Swift
- **docs/swift-observable.mdc** - Observable framework patterns (@Observable, @ObservationTracked)
- **docs/swift-observation.mdc** - Swift Observation framework details
- **docs/swiftui_dependency_injection.md** - Dependency injection patterns in SwiftUI
- **docs/convert_to_combine.md** - Guide for converting to Combine framework

### Core Feature Documentation
- **docs/preloading_and_cacheing.md** - Comprehensive video caching and preloading architecture
- **docs/avurlasset_preloading_management.md** - AVURLAsset preloading implementation details
- **docs/app_launch_video_loading.md** - App launch video loading sequence and patterns
- **docs/how_to_implement_buffering_indicator.md** - Buffering indicator UI implementation guide
- **docs/double_speed_playback.md** - Playback speed control implementation
- **docs/updated_trimming_details_051020205.md** - Video trimming functionality and UI details

### Business Logic Documentation
- **docs/favorites_business_logic.md** - Favorites system business rules and user intent
- **docs/preferences_business_logic.md** - Preferences and preset system business logic

### API Integration Guides
- **docs/archive_org_api_reference.md** - Complete Archive.org API integration reference
- **docs/pinecone_search.md** - Pinecone vector search integration guide
- **docs/pinecone_search_implementation_plan.md** - Implementation plan for semantic search
- **docs/secure_api_keys.md** - API key security best practices

### Architecture & Refactoring Guides
- **docs/notification_architecture_update.md** - Notification system architecture patterns
- **docs/notification_behaviors_baseline.md** - Baseline notification behavior documentation
- **docs/refactor_for_testing_improvement.md** - Refactoring guidelines for better testability
- **docs/remove_global_identifiers.md** - Guide for removing global state dependencies

### Testing Documentation
- **docs/swifttesting_documentation.md** - Comprehensive Swift Testing framework guide
- **docs/swift_testing_timing_patterns.md** - Testing timing and async patterns
- **docs/testing_async_notification_patterns.md** - Async notification testing strategies

### Infrastructure & Environment
- **docs/xcode_cloud_env.md** - Xcode Cloud environment setup and configuration

### Data Files
- **docs/avgeeks_identifiers.txt** - List of video identifiers from the avgeeks collection