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
    @Published var cacheStatuses: [CacheStatus] = [.notCached, .notCached, .notCached]
    
    // MARK: - Cache Status Update Timer
    private var cacheStatusTask: Task<Void, Never>?
    private var cacheStatusPaused = false

    // MARK: - Initialization
    init() {
        setupAudioSession()
        setupDurationObserver()
        startCacheStatusUpdates()

        // Listen for cache status change notifications
        NotificationCenter.default.addObserver(
            forName: Notification.Name("CacheStatusChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Log that we received the notification
            Logger.caching.info("📱 RECEIVED NOTIFICATION: CacheStatusChanged in \(String(describing: type(of: self)))")

            // Update cache status immediately when notification received
            Task {
                Logger.caching.info("🔄 UPDATING UI: updateCacheStatuses called due to notification")
                await self?.updateCacheStatuses()
            }
        }

        // Listen for cache system restart requests
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CacheSystemNeedsRestart"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }

            Logger.caching.warning("🚨 RECOVERY: Received CacheSystemNeedsRestart notification")

            // Only the VideoPlayerViewModel has all the components needed to restart caching
            if let videoPlayerViewModel = self as? VideoPlayerViewModel,
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

    private func startCacheStatusUpdates() {
        cacheStatusTask?.cancel()

        cacheStatusTask = Task {
            // Update every second - less frequently to reduce log noise
            while !Task.isCancelled {
                // Only update if not paused
                if !cacheStatusPaused {
                    await updateCacheStatuses()
                }

                // Wait before checking again
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    break
                }
            }
        }
    }

    /// Pauses background operations like cache status updates
    func pauseBackgroundOperations() async {
        Logger.caching.info("⏸️ PAUSE: BaseVideoViewModel pausing background operations")
        cacheStatusPaused = true
    }

    /// Resumes background operations that were paused
    func resumeBackgroundOperations() async {
        Logger.caching.info("▶️ RESUME: BaseVideoViewModel resuming background operations")
        cacheStatusPaused = false

        // Immediately update cache status when resuming
        await updateCacheStatuses()
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
            } else {
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
        playbackManager.cleanupPlayer()

        // Cancel the cache status update task
        cacheStatusTask?.cancel()
        cacheStatusTask = nil

        // Remove notification observer
        NotificationCenter.default.removeObserver(self, name: Notification.Name("CacheStatusChanged"), object: nil)

        // Other async cleanup can be done in a Task
        Task {
            // Any additional async cleanup could go here
        }
    }
    
    // MARK: - VideoControlProvider Protocol Conformance

    var isFavorite: Bool {
        false // Default implementation, to be overridden by subclasses
    }

    var isIdentifierSaved: Bool {
        guard let identifier = currentIdentifier else { return false }
        return UserSelectedIdentifiersManager.shared.contains(identifier: identifier)
    }

    func toggleFavorite() {
        // Default implementation does nothing, to be overridden by subclasses
    }

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
        
        // Notify to show the preset selection view for this identifier
        NotificationCenter.default.post(
            name: Notification.Name("ShowPresetSelection"),
            object: nil,
            userInfo: [
                "identifier": identifier,
                "title": title,
                "collection": collection
            ]
        )
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

                // Update cache statuses
                await updateCacheStatuses()
            } else {
                // Fallback to just preloading next and previous videos
                Logger.caching.warning("BaseVideoViewModel.ensureVideosAreCached: No transition manager available, using basic preloading")

                // Still try to preload videos if possible
                async let nextTask = videoProvider.getNextVideo()
                async let prevTask = videoProvider.getPreviousVideo()
                _ = await (nextTask, prevTask)

                // Update cache statuses
                await updateCacheStatuses()
            }
        } else {
            Logger.caching.error("BaseVideoViewModel.ensureVideosAreCached: Failed - not a VideoProvider")
        }
    }

    /// Updates the cache statuses based on the current video and cache state
    /// This method should be called whenever the cache state changes
    func updateCacheStatuses() async {
        guard let identifier = currentIdentifier else {
            return
        }

        if let cacheableProvider = self as? CacheableProvider {
            // Get transition manager if provider conforms to VideoProvider
            var transitionManager: VideoTransitionManager? = nil
            if let videoProvider = self as? VideoProvider {
                transitionManager = videoProvider.transitionManager

                // DEBUG: Log the transition manager identity to help debug issues
                if let manager = transitionManager {
                    Logger.caching.info("🔍 USING TRANSITION MANAGER: \(String(describing: ObjectIdentifier(manager))), nextReady=\(manager.nextVideoReady), prevReady=\(manager.prevVideoReady)")
                }
            }

            // Get cache statuses from the cache manager with transition manager context
            // The VideoCacheManager.getCacheStatuses implementation now directly uses
            // transition manager's nextVideoReady state for the UI indicators
            let statuses = await cacheableProvider.cacheManager.getCacheStatuses(
                currentVideoIdentifier: identifier,
                transitionManager: transitionManager
            )

            // Update on the main thread since we're modifying @Published properties
            await MainActor.run {
                self.cacheStatuses = statuses
            }
        }
    }
}