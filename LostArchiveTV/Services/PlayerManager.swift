//
//  PlayerManager.swift
//  LostArchiveTV
//
//  Created by Claude on 4/25/25.
//

import Foundation
import AVFoundation
import OSLog

/// A centralized manager for AVPlayer functionality that is used across the app
/// to reduce code duplication and provide consistent player handling.
class PlayerManager: ObservableObject {
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

    // MARK: - Player Properties
    
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
        Logger.videoPlayback.debug("PlayerManager initialized")
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

        Logger.videoPlayback.debug("🧹 PLAYER_CLEANUP: Starting cleanup for player \(playerPointerStr), item status: \(playerItemStatus)")

        // Remove time observer
        if let timeObserverToken = timeObserverToken, let player = player {
            Logger.videoPlayback.debug("🧹 PLAYER_CLEANUP: Removing time observer")
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }

        // Remove notification observers
        if let currentItem = player?.currentItem {
            Logger.videoPlayback.debug("🧹 PLAYER_CLEANUP: Removing notification observers for item with status: \(currentItem.status.rawValue)")
            NotificationCenter.default.removeObserver(
                self,
                name: .AVPlayerItemDidPlayToEndTime,
                object: currentItem
            )
        }

        // Log URL before clearing
        if let url = _currentVideoURL {
            Logger.videoPlayback.debug("🧹 PLAYER_CLEANUP: Clearing URL: \(url.lastPathComponent)")
        }

        // Stop and clear player
        Logger.videoPlayback.debug("🧹 PLAYER_CLEANUP: Pausing and replacing player item with nil")
        player?.pause()
        player?.replaceCurrentItem(with: nil)

        Logger.videoPlayback.debug("🧹 PLAYER_CLEANUP: Setting player to nil and resetting state")
        player = nil
        isPlaying = false
        currentTime = 0
        videoDuration = 0
        _currentVideoURL = nil

        Logger.videoPlayback.debug("🧹 PLAYER_CLEANUP: Cleanup complete")
    }
}