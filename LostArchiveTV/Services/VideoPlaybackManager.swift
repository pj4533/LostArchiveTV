//
//  VideoPlaybackManager.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import Foundation
import AVFoundation
import OSLog

/// Consolidated video playback manager that directly handles AVPlayer functionality
/// This class provides a centralized interface for all video playback operations.
class VideoPlaybackManager: ObservableObject {
    // MARK: - Published Properties
    @Published var player: AVPlayer?
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var videoDuration: Double = 0

    // MARK: - Internal Properties
    internal var timeObserverToken: Any?
    internal var _currentVideoURL: URL?
    internal let audioSessionManager = AudioSessionManager()
    internal var normalPlaybackRate: Float = 1.0

    // MARK: - Computed Properties
    var currentVideoURL: URL? {
        return _currentVideoURL
    }
    
    var currentTimeAsCMTime: CMTime? {
        guard let player = player else { return nil }
        return player.currentItem?.currentTime()
    }
    
    var durationAsCMTime: CMTime? {
        guard let player = player else { return nil }
        return player.currentItem?.duration
    }
    
    // MARK: - Initialization
    init() {
        Logger.videoPlayback.debug("🎮 VP_MANAGER: VideoPlaybackManager initialized")
        
        // Configure audio session
        setupAudioSession()
    }
    
    deinit {
        cleanupPlayer()
    }
    
    // MARK: - Audio Session Management
    
    /// Configures the audio session for optimal playback
    func setupAudioSession(forTrimming: Bool = false) {
        if forTrimming {
            audioSessionManager.configureForTrimming()
        } else {
            audioSessionManager.configureForPlayback()
        }
    }
    
    /// Deactivates the audio session when done with playback
    func deactivateAudioSession() {
        audioSessionManager.deactivate()
    }
    
    // MARK: - Cleanup
    
    /// Cleans up all player resources
    func cleanupPlayer() {
        // Get player identifier for logging before cleanup
        var playerPointerStr = "nil"
        var playerItemStatus = -1
        if let existingPlayer = player {
            playerPointerStr = String(describing: ObjectIdentifier(existingPlayer))
            playerItemStatus = existingPlayer.currentItem?.status.rawValue ?? -1
        }

        Logger.videoPlayback.debug("🧹 VP_MANAGER: Starting cleanup for player \(playerPointerStr), item status: \(playerItemStatus)")

        // Remove time observer
        if let timeObserverToken = timeObserverToken, let player = player {
            Logger.videoPlayback.debug("🧹 VP_MANAGER: Removing time observer")
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }

        // Remove notification observers
        if let currentItem = player?.currentItem {
            Logger.videoPlayback.debug("🧹 VP_MANAGER: Removing notification observers for item with status: \(currentItem.status.rawValue)")
            NotificationCenter.default.removeObserver(
                self,
                name: .AVPlayerItemDidPlayToEndTime,
                object: currentItem
            )
        }

        // Log URL before clearing
        if let url = _currentVideoURL {
            Logger.videoPlayback.debug("🧹 VP_MANAGER: Clearing URL: \(url.lastPathComponent)")
        }

        // Stop and clear player
        Logger.videoPlayback.debug("🧹 VP_MANAGER: Pausing and replacing player item with nil")
        player?.pause()
        player?.replaceCurrentItem(with: nil)

        Logger.videoPlayback.debug("🧹 VP_MANAGER: Setting player to nil and resetting state")
        player = nil
        isPlaying = false
        currentTime = 0
        videoDuration = 0
        _currentVideoURL = nil

        Logger.videoPlayback.debug("🧹 VP_MANAGER: Cleanup complete")
    }
}