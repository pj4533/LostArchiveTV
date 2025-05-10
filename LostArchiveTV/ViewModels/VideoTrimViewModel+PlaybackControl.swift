//
//  VideoTrimViewModel+PlaybackControl.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import Foundation
import AVKit
import AVFoundation
import OSLog

// MARK: - Playback Control
extension VideoTrimViewModel {
    
    func togglePlayback() {
        // Get the current state for logging
        let wasPlaying = isPlaying

        // Toggle the state, but do it properly based on player actions
        isPlaying.toggle()
        logger.debug("▶️ TRIM_PLAYBACK: Toggling playback from \(wasPlaying) to \(self.isPlaying)")

        if isPlaying {
            // Verify we have a valid player - if not, log an error
            if playbackManager.player == nil {
                logger.error("⚠️ TRIM_PLAYBACK: Player is nil! Cannot continue with playback")

                // Reset playback state
                isPlaying = false
                return
            }

            // CRITICAL: Configure audio session before playing
            logger.debug("🔊 TRIM_PLAYBACK: Configuring audio session for playback")
            audioSessionManager.configureForPlayback()

            // Start the playhead update timer immediately
            startPlayheadUpdateTimer()

            // If right handle was the last one dragged, always start from the left handle
            if lastDraggedRightHandle {
                logger.debug("▶️ TRIM_PLAYBACK: Starting from left handle after right handle drag")
                lastDraggedRightHandle = false // Reset flag once used

                // Seek to start and play
                seekToTime(startTrimTime)
                playbackManager.player?.play()
                logger.debug("▶️ TRIM_PLAYBACK: Started playback from start trim time: \(self.startTrimTime.seconds)s")
                return
            }

            // Get the player and verify it's in a valid state
            if let player = playbackManager.player, let playerItem = player.currentItem {
                // Log player status for debugging
                let itemStatus = playerItem.status.rawValue
                logger.debug("🔍 TRIM_PLAYBACK: Player item status before playback: \(itemStatus)")

                // Check if current time is within trim bounds
                let currentPlayerTime = player.currentTime()
                logger.debug("🔍 TRIM_PLAYBACK: Current player time: \(currentPlayerTime.seconds)s")

                if CMTimeCompare(currentPlayerTime, startTrimTime) < 0 ||
                   CMTimeCompare(currentPlayerTime, endTrimTime) > 0 {
                    // If outside trim bounds, seek to start and play from there
                    logger.debug("⏱️ TRIM_PLAYBACK: Current time outside trim bounds, seeking to start")
                    seekToTime(startTrimTime)

                    // Explicitly start playback
                    player.play()
                    logger.debug("▶️ TRIM_PLAYBACK: Started playback after seeking to start trim time")
                } else {
                    // Otherwise just play from current position
                    logger.debug("▶️ TRIM_PLAYBACK: Playing from current position: \(currentPlayerTime.seconds)s")
                    player.play()
                }
            } else {
                // Log the issue
                logger.error("⚠️ TRIM_PLAYBACK: Player or player item is nil, cannot start playback normally")

                // Reset playback state
                isPlaying = false
            }
        } else {
            // Stop the timer when paused
            logger.debug("⏸️ TRIM_PLAYBACK: Pausing playback")
            stopPlayheadUpdateTimer()

            // Make sure to use the actual player instance if available
            if let player = playbackManager.player {
                player.pause()
                player.rate = 0 // Explicitly set rate to 0 to ensure it's really paused
                let playerID = String(describing: ObjectIdentifier(player))
                logger.debug("⏸️ TRIM_PLAYBACK: Playback paused, player ID: \(playerID)")
            } else {
                logger.error("⚠️ TRIM_PLAYBACK: Cannot pause - player is nil")
            }
        }
        
        // Show the play button again when interacting with the timeline, dragging handles, or tapping the video
        // This is handled in the UI layer by setting shouldShowPlayButton = false when button is tapped
    }
    
    // Use a simple timer to update the playhead position during playback
    func startPlayheadUpdateTimer() {
        // Stop any existing timer first
        stopPlayheadUpdateTimer()

        // Create a timer that fires 10 times per second
        playheadUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            // Capture the current state inside timer callback to avoid Sendable warnings
            let isCurrentlyPlaying = self.isPlaying
            guard isCurrentlyPlaying, let player = self.playbackManager.player else { return }

            // Update our currentTime property with the player's current time
            let time = player.currentTime()
            self.currentTime = time

            // Capture endTrimTime locally to avoid Sendable issues
            let endTime = self.endTrimTime

            // Check if we've reached the end of the trim range
            if CMTimeCompare(time, endTime) >= 0 {
                self.logger.debug("⏱️ TRIM_LOOP: Reached end of trim section, looping back")
                let startTime = self.startTrimTime
                self.seekToTime(startTime)
            }
        }
    }
    
    func stopPlayheadUpdateTimer() {
        playheadUpdateTimer?.invalidate()
        playheadUpdateTimer = nil
    }
    
    func seekToTime(_ time: CMTime, fromHandleDrag: Bool = false) {
        // Log seek operation
        logger.debug("trim: seeking to \(time.seconds) seconds, fromHandleDrag=\(fromHandleDrag)")

        // Update currentTime immediately so the playhead updates right away
        self.currentTime = time

        guard let player = playbackManager.player else {
            logger.error("trim: seekToTime failed - player is nil")
            return
        }

        // Make sure the time is within bounds
        let validTime = validateTimeForSeeking(time)

        // Perform the seek operation with more precise tolerances
        player.seek(to: validTime,
                   toleranceBefore: .zero,
                   toleranceAfter: .zero) { [weak self] completed in
            guard let self = self else {
                return
            }

            if !completed {
                self.logger.error("trim: seek operation did not complete")
                return
            }

            self.logger.debug("trim: seek completed to \(validTime.seconds) seconds")

            // Update UI to reflect the actual position after seeking
            self.currentTime = player.currentTime()

            // Only restart playback if not from handle dragging and already in playing state
            if self.isPlaying && !fromHandleDrag {
                self.playbackManager.player?.play()
                self.logger.debug("trim: playback resumed after seek")
            }
        }
    }
    
    /// Ensures the seek time is within the valid range
    private func validateTimeForSeeking(_ time: CMTime) -> CMTime {
        // Get the asset duration for bounds checking
        let duration = assetDuration
        
        // Make sure time is not before the start of the asset
        if CMTimeCompare(time, CMTime.zero) < 0 {
            logger.debug("trim: clamping seek time to start of asset")
            return CMTime.zero
        }
        
        // Make sure time is not past the end of the asset
        if CMTimeCompare(time, duration) > 0 {
            logger.debug("trim: clamping seek time to end of asset")
            return duration
        }
        
        return time
    }
}