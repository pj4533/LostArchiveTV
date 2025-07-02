//
//  BaseVideoViewModel.swift
//  LostArchiveTV
//
//  Created by Claude on 4/25/25.
//

import Foundation
import AVKit
import AVFoundation
import OSLog
import SwiftUI
import Combine

/// Base class for video view models that implements common functionality
@MainActor
class BaseVideoViewModel: ObservableObject, VideoDownloadable, VideoControlProvider, VideoPlaybackManagerDelegate {
    // MARK: - Common Services
    let playbackManager = VideoPlaybackManager()
    let downloadViewModel = VideoDownloadViewModel()
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentIdentifier: String?
    @Published var currentCollection: String?
    @Published var currentTitle: String?
    @Published var currentDescription: String?
    @Published var currentFilename: String?
    @Published var videoDuration: Double = 0
    @Published var totalFiles: Int = 0
    
    // MARK: - Buffering Monitors
    @Published var currentBufferingMonitor: BufferingMonitor?
    @Published var nextBufferingMonitor: BufferingMonitor?
    @Published var previousBufferingMonitor: BufferingMonitor?
    
    
    // MARK: - Combine
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init() {
        // Initialize buffering monitors
        currentBufferingMonitor = BufferingMonitor()
        nextBufferingMonitor = BufferingMonitor()
        previousBufferingMonitor = BufferingMonitor()
        
        setupAudioSession()
        setupDurationObserver()

        // Listen for buffer status changes using Combine
        TransitionPreloadManager.bufferStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] bufferState in
                // Log that we received the notification
                Logger.caching.info("📱 RECEIVED COMBINE EVENT: BufferStatusChanged to \(bufferState.description) in \(String(describing: type(of: self)))")

                // Update buffering monitors for preloaded videos
                Task {
                    await MainActor.run {
                        self?.updatePreloadedBufferingMonitors()
                    }
                }
            }
            .store(in: &cancellables)
    }

    
    // MARK: - Setup Functions
    
    func setupAudioSession() {
        playbackManager.setupAudioSession()
    }
    
    func setupDurationObserver() {
        Task {
            for await _ in playbackManager.$videoDuration.values {
                self.videoDuration = playbackManager.videoDuration
            }
        }
    }
    
    // MARK: - Player Controls
    
    var player: AVPlayer? {
        get { playbackManager.player }
        set {
            Logger.videoPlayback.info("📍 PLAYER_INIT: BaseVideoViewModel.player setter called with player: \(newValue != nil ? "non-nil" : "nil")")
            if let newPlayer = newValue {
                Logger.videoPlayback.info("📍 PLAYER_INIT: Setting new player in playbackManager")
                playbackManager.delegate = self
                playbackManager.useExistingPlayer(newPlayer)
                // Connect the buffering monitor to the new player
                Logger.videoPlayback.info("📍 PLAYER_INIT: Connecting current buffer monitor to new player")
                playbackManager.connectBufferingMonitor(currentBufferingMonitor)
            } else {
                // Disconnect monitor before cleanup
                Logger.videoPlayback.info("📍 PLAYER_INIT: Player set to nil, disconnecting buffer monitor and cleaning up")
                playbackManager.disconnectBufferingMonitor(currentBufferingMonitor)
                playbackManager.cleanupPlayer()
            }
        }
    }
    
    func pausePlayback() async {
        Logger.videoPlayback.debug("Pausing playback")
        playbackManager.pause()
    }
    
    func resumePlayback() async {
        Logger.videoPlayback.debug("Resuming playback")
        playbackManager.play()
    }
    
    func restartVideo() {
        Logger.videoPlayback.info("Restarting video from the beginning")
        playbackManager.seekToBeginning()
    }
    
    var isPlaying: Bool {
        playbackManager.isPlaying
    }
    
    // MARK: - Video Trimming Support
    
    var currentVideoURL: URL? {
        playbackManager.currentVideoURL
    }
    
    var currentVideoTime: CMTime? {
        playbackManager.currentTimeAsCMTime
    }
    
    var currentVideoDuration: CMTime? {
        playbackManager.durationAsCMTime
    }
    
    // MARK: - Player Access
    // Implementation of player property from VideoProvider protocol
    // We're just delegating to the playbackManager
    
    // MARK: - Cleanup

    func cleanup() {
        // Stop playback immediately
        playbackManager.pause()
        
        // Disconnect buffering monitor before cleanup
        playbackManager.disconnectBufferingMonitor(currentBufferingMonitor)
        
        playbackManager.cleanupPlayer()

        // Cancel Combine subscriptions
        cancellables.removeAll()
        
        // Stop all buffering monitors
        currentBufferingMonitor?.stopMonitoring()
        nextBufferingMonitor?.stopMonitoring()
        previousBufferingMonitor?.stopMonitoring()

        // Other async cleanup can be done in a Task
        Task {
            // Any additional async cleanup could go here
        }
    }
    
    // MARK: - VideoControlProvider Protocol Conformance

    var isFavorite: Bool {
        false // Default implementation, to be overridden by subclasses
    }

    // This property was removed as it's no longer needed with the preset system
    // Identifiers can now be added to multiple presets

    func toggleFavorite() {
        // Default implementation does nothing, to be overridden by subclasses
    }

    // Add published property to control sheet presentation
    @Published var isShowingPresetSelection = false

    // Struct to hold preset selection data for the sheet
    struct PresetSelectionData {
        let identifier: String
        let collection: String
        let title: String
        let fileCount: Int
    }
    
    // Data to pass to the preset selection sheet
    @Published var presetSelectionData: PresetSelectionData?
    
    func saveIdentifier() async {
        // This is now just a wrapper for showing the preset selection sheet
        await showPresetSelection()
    }
    
    func showPresetSelection() async {
        guard let identifier = currentIdentifier,
              let collection = currentCollection,
              let title = currentTitle else {
            return
        }
        
        // Pause the video first
        await pausePlayback()
        
        // Set the data to pass to the sheet
        await MainActor.run {
            self.presetSelectionData = PresetSelectionData(
                identifier: identifier,
                collection: collection,
                title: title,
                fileCount: self.totalFiles
            )
            
            // Show the sheet
            self.isShowingPresetSelection = true
        }
    }
    
    // Called when preset selection is complete
    func onPresetSelectionComplete(saved: Bool, presetName: String? = nil) {
        // Dismiss the sheet
        isShowingPresetSelection = false
        
        // Reset the data
        presetSelectionData = nil
    }
    
    func setTemporaryPlaybackRate(rate: Float) {
        Logger.videoPlayback.debug("Setting temporary playback rate to \(rate)")
        playbackManager.setTemporaryPlaybackRate(rate: rate)
    }
    
    func resetPlaybackRate() {
        Logger.videoPlayback.debug("Resetting playback rate")
        playbackManager.resetPlaybackRate()
    }
    
    // MARK: - Error Handling
    
    /// Handles errors with improved user messaging, especially for connection issues
    /// - Parameter error: The error to handle and display to the user
    func handleError(_ error: Error) {
        Logger.videoPlayback.error("Handling error: \(error.localizedDescription)")
        
        // Check if it's a NetworkError for specialized handling
        if let networkError = error as? NetworkError {
            switch networkError {
            case .connectionError, .timeout, .noInternetConnection:
                // For connection errors, provide actionable feedback
                errorMessage = networkError.localizedDescription
            case .serverError(let statusCode, _):
                // For server errors, provide status code context
                if statusCode >= 500 {
                    errorMessage = "Server is temporarily unavailable. Please try again in a moment."
                } else if statusCode == 404 {
                    errorMessage = "The requested video could not be found. Trying another video..."
                } else {
                    errorMessage = networkError.localizedDescription
                }
            default:
                // For other network errors, use the localized description
                errorMessage = networkError.localizedDescription
            }
        } else {
            // For non-network errors, provide generic message
            errorMessage = "Error loading video: \(error.localizedDescription)"
        }
    }
    
    /// Clears any existing error message
    func clearError() {
        errorMessage = nil
    }
    
    /// Checks if the current error is a connection-related error
    /// - Returns: True if the error indicates a connection issue
    var hasConnectionError: Bool {
        guard let errorMessage = errorMessage else { return false }
        let lowercaseMessage = errorMessage.lowercased()
        return lowercaseMessage.contains("connection") || 
               lowercaseMessage.contains("internet") || 
               lowercaseMessage.contains("network") ||
               lowercaseMessage.contains("timed out") ||
               lowercaseMessage.contains("timeout")
    }
    
    // MARK: - Video Caching

    /// Ensures videos are properly cached for smooth playback
    /// This base implementation uses the transition manager's ensureAllCaching method
    /// which will handle both general caching and transition-specific caching
    func ensureVideosAreCached() async {
        if let videoProvider = self as? VideoProvider {
            if let transitionManager = videoProvider.transitionManager {
                // Use the comprehensive ensureAllVideosCached method from TransitionPreloadManager
                // This handles both general caching and transition preloading in one call
                Logger.caching.info("BaseVideoViewModel.ensureVideosAreCached: Using transition manager's unified caching")
                await transitionManager.ensureAllVideosCached(provider: videoProvider)

                // Update buffering monitors for preloaded videos
                await MainActor.run {
                    updatePreloadedBufferingMonitors()
                }
            } else {
                // Fallback to just preloading next and previous videos
                Logger.caching.warning("BaseVideoViewModel.ensureVideosAreCached: No transition manager available, using basic preloading")

                // Still try to preload videos if possible
                async let nextTask = videoProvider.getNextVideo()
                async let prevTask = videoProvider.getPreviousVideo()
                _ = await (nextTask, prevTask)

                // Update buffering monitors for preloaded videos
                await MainActor.run {
                    updatePreloadedBufferingMonitors()
                }
            }
        } else {
            Logger.caching.error("BaseVideoViewModel.ensureVideosAreCached: Failed - not a VideoProvider")
        }
    }

    
    // MARK: - Buffering Monitor Management
    
    /// Updates buffering monitors for preloaded videos
    /// Call this when preloaded videos change
    func updatePreloadedBufferingMonitors() {
        guard let videoProvider = self as? VideoProvider,
              let transitionManager = videoProvider.transitionManager else {
            return
        }
        
        // Connect monitors to preloaded players
        if let nextPlayer = transitionManager.nextPlayer {
            Logger.videoPlayback.debug("🔍 Connecting next video buffering monitor")
            Logger.preloading.info("🔗 MONITOR CONNECTION: Connecting nextBufferingMonitor to nextPlayer \(String(describing: Unmanaged.passUnretained(nextPlayer).toOpaque()))")
            nextBufferingMonitor?.stopMonitoring()
            nextBufferingMonitor?.startMonitoring(nextPlayer)
        } else {
            Logger.preloading.warning("⚠️ MONITOR CONNECTION: No nextPlayer available to connect monitor")
            nextBufferingMonitor?.stopMonitoring()
        }
        
        if let prevPlayer = transitionManager.prevPlayer {
            Logger.videoPlayback.debug("🔍 Connecting previous video buffering monitor")
            Logger.preloading.info("🔗 MONITOR CONNECTION: Connecting previousBufferingMonitor to prevPlayer")
            previousBufferingMonitor?.stopMonitoring()
            previousBufferingMonitor?.startMonitoring(prevPlayer)
        } else {
            Logger.preloading.warning("⚠️ MONITOR CONNECTION: No prevPlayer available to connect monitor")
            previousBufferingMonitor?.stopMonitoring()
        }
    }
    
    // MARK: - Helper Properties for UI
    
    /// Current video title for display in BufferingIndicatorView
    var currentVideoTitle: String {
        return currentTitle ?? "Unknown Video"
    }
    
    /// Next video title for display in BufferingIndicatorView
    var nextVideoTitle: String {
        guard let videoProvider = self as? VideoProvider,
              let transitionManager = videoProvider.transitionManager else {
            return "Next Video"
        }
        return transitionManager.nextTitle.isEmpty ? "Next Video" : transitionManager.nextTitle
    }
    
    /// Previous video title for display in BufferingIndicatorView
    var previousVideoTitle: String {
        guard let videoProvider = self as? VideoProvider,
              let transitionManager = videoProvider.transitionManager else {
            return "Previous Video"
        }
        return transitionManager.prevTitle.isEmpty ? "Previous Video" : transitionManager.prevTitle
    }
    
    // MARK: - VideoPlaybackManagerDelegate
    
    nonisolated func playerEncounteredError(_ error: Error, for player: AVPlayer) {
        Logger.videoPlayback.error("🚨 BaseVideoViewModel: Player encountered error: \(error.localizedDescription)")
        
        Task { @MainActor in
            // Check if it's a content failure (not a network error)
            if isContentFailure(error) {
                // Handle content failure silently
                handleContentFailure()
            } else {
                // For network errors, use the existing error handling
                handleError(error)
            }
        }
    }
    
    // MARK: - Content Failure Handling
    
    /// Determines if an error is a content failure (format/codec issue) vs network error
    private func isContentFailure(_ error: Error) -> Bool {
        let nsError = error as NSError
        
        // Check for AVFoundation error domains and codes that indicate content issues
        if nsError.domain == AVFoundationErrorDomain {
            switch nsError.code {
            case AVError.decoderNotFound.rawValue,
                 AVError.decoderTemporarilyUnavailable.rawValue,
                 AVError.undecodableMediaData.rawValue,
                 AVError.failedToParse.rawValue,
                 AVError.fileTypeDoesNotSupportSampleReferences.rawValue:
                return true
            default:
                break
            }
        }
        
        // Check error description for content-related keywords
        let errorDescription = error.localizedDescription.lowercased()
        let contentKeywords = ["decode", "codec", "format", "unsupported", "corrupt", "damaged", "invalid"]
        
        return contentKeywords.contains { errorDescription.contains($0) }
    }
    
    /// Handles content failures by silently moving to the next video
    private func handleContentFailure() {
        Logger.videoPlayback.warning("⚠️ BaseVideoViewModel: Content failure detected, silently moving to next video")
        
        // Clear any existing error message to ensure silent handling
        errorMessage = nil
        
        // Check if we're a VideoProvider to access the transition manager
        guard let videoProvider = self as? VideoProvider,
              let transitionManager = videoProvider.transitionManager else {
            Logger.videoPlayback.error("❌ BaseVideoViewModel: Cannot handle content failure - not a VideoProvider or no transition manager")
            return
        }
        
        // Get the feed type by checking the concrete type of self
        let feedType: String
        switch self {
        case is VideoPlayerViewModel:
            feedType = "main"
        case is SearchViewModel:
            feedType = "search"
        case is FavoritesViewModel:
            feedType = "favorites"
        default:
            feedType = "unknown"
        }
        
        Logger.videoPlayback.info("🔄 BaseVideoViewModel: Handling content failure for \(feedType) feed")
        
        // Use a Task to handle the async transition
        Task { @MainActor in
            // For content failures, we want to silently move to the next video
            // We'll use the VideoProvider's getNextVideo method and handle the transition manually
            
            Logger.videoPlayback.info("🔄 BaseVideoViewModel: Getting next video for content failure recovery")
            
            // Get the next video
            if let nextVideo = await videoProvider.getNextVideo() {
                // Stop current playback
                self.playbackManager.pause()
                
                // Clean up current player
                self.playbackManager.cleanupPlayer()
                
                // Update all the metadata
                self.currentIdentifier = nextVideo.identifier
                self.currentTitle = nextVideo.title
                self.currentCollection = nextVideo.collection
                self.currentDescription = nextVideo.description
                self.currentFilename = nil // CachedVideo doesn't have filename
                self.totalFiles = nextVideo.totalFiles
                
                // Create new player with the asset
                self.playbackManager.createNewPlayer(from: nextVideo.asset, url: nextVideo.videoURL, startPosition: nextVideo.startPosition)
                
                // Set the player reference
                self.player = self.playbackManager.player
                
                // Start playback
                self.playbackManager.play()
                
                // Ensure videos are cached for smooth transitions
                await self.ensureVideosAreCached()
                
                Logger.videoPlayback.info("✅ BaseVideoViewModel: Content failure recovery complete for \(feedType) feed - loaded \(nextVideo.identifier)")
            } else {
                Logger.videoPlayback.error("❌ BaseVideoViewModel: Failed to get next video for content failure recovery")
                
                // As a last resort, show an error to the user
                self.errorMessage = "Unable to load next video. Please try again."
            }
        }
    }
}