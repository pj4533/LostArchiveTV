# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
- LostArchiveTV is an app that plays random videos from the Internet Archive
- Uses the Archive.org API to fetch metadata and stream videos
- Implements a TikTok-style video player with random clip selection
- Features video preloading and caching for smoother playback experience

## Build and Test Commands
- Build app: `xcodebuild -scheme LostArchiveTV -destination 'platform=iOS Simulator,name=iPhone 16' build`
- Build and check for errors: `xcodebuild -scheme LostArchiveTV -destination 'platform=iOS Simulator,name=iPhone 16' build | grep -A 2 "error:" || echo "Build successful - no errors found"`
- Run tests: `xcodebuild -scheme LostArchiveTV -destination 'platform=iOS Simulator,name=iPhone 16' test`
- Run single test: `xcodebuild -scheme LostArchiveTV -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:LostArchiveTVTests/[TestName]`
- Verify build after making changes: Run the build command to ensure there are no errors

## Project Structure
- Organized into separate Models, Views, ViewModels, and Services directories
- Models in `Models/` directory: ArchiveIdentifier, ArchiveMetadata, ArchiveFile, ItemMetadata, CachedVideo
- Views in `Views/` directory: ContentView, PlayerContentView, LoadingView, ErrorView, HeaderView
- Services in `Services/` directory: ArchiveService, VideoCacheManager, VideoPlaybackManager, PreloadService, LoggingService
- Video coordination in `VideoPlayerViewModel.swift`
- App entry point in `LostArchiveTVApp.swift`
- Video identifiers stored in `avgeeks_identifiers.json`

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
- Leverage OSLog for structured logging across different categories
- Use descriptive variable names following Swift conventions (camelCase)
- Implement robust error handling and recovery