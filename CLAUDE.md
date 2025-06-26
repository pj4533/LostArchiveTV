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