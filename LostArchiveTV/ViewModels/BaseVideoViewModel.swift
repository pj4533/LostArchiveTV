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
class BaseVideoViewModel: ObservableObject, VideoDownloadable, VideoControlProvider {
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

        // Listen for cache system restart requests
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CacheSystemNeedsRestart"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }

            Logger.caching.warning("🚨 RECOVERY: Received CacheSystemNeedsRestart notification")

            // Only the VideoPlayerViewModel has all the components needed to restart caching
            if let _ = self as? VideoPlayerViewModel,
               let cacheableProvider = self as? CacheableProvider {
                Task {
                    Logger.caching.warning("🔄 FORCE RESTART: Attempting emergency cache restart in BaseVideoViewModel")

                    // FIXED: Instead of calling ensureVideosAreCached() which would trigger both preloading AND caching,
                    // directly call cacheService.ensureVideosAreCached() which only handles caching
                    Logger.caching.warning("🔄 FORCE RESTART: Directly calling cacheService.ensureVideosAreCached to avoid unnecessary preloading")
                    await cacheableProvider.cacheService.ensureVideosAreCached(
                        cacheManager: cacheableProvider.cacheManager,
                        archiveService: cacheableProvider.archiveService,
                        identifiers: cacheableProvider.getIdentifiersForGeneralCaching()
                    )

                    Logger.caching.warning("✅ FORCE RESTART: Emergency cache restart executed")
                }
            }
        }
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
            if let newPlayer = newValue {
                playbackManager.useExistingPlayer(newPlayer)
                // Connect the buffering monitor to the new player
                playbackManager.connectBufferingMonitor(currentBufferingMonitor)
            } else {
                // Disconnect monitor before cleanup
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
            nextBufferingMonitor?.stopMonitoring()
            nextBufferingMonitor?.startMonitoring(nextPlayer)
        } else {
            nextBufferingMonitor?.stopMonitoring()
        }
        
        if let prevPlayer = transitionManager.prevPlayer {
            Logger.videoPlayback.debug("🔍 Connecting previous video buffering monitor")
            previousBufferingMonitor?.stopMonitoring()
            previousBufferingMonitor?.startMonitoring(prevPlayer)
        } else {
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
}