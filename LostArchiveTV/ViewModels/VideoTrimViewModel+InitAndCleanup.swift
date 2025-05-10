//
//  VideoTrimViewModel+InitAndCleanup.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import Foundation
import AVKit
import AVFoundation
import OSLog
import Photos

// MARK: - Initialization and Cleanup
extension VideoTrimViewModel {
    /// Initialize the player and prepare for video trimming
    func prepareForTrimming() async {
        logger.debug("Preparing for trimming started")
        self.isLoading = true

        // Set global trim mode flag to optimize performance
        EnvironmentService.isInTrimMode = true

        // Pause background processes that could affect performance
        Task {
            let preloadService = PreloadService()
            await preloadService.pausePreloading()
            logger.debug("🧹 TRIM: Paused PreloadService")
        }

        // Disable transition manager to prevent background operations
        VideoTransitionManager().disableForTrimming()
        logger.debug("🧹 TRIM: Disabled VideoTransitionManager")

        do {
            // Verify the file exists and has content
            logger.debug("Checking file at path: \(self.assetURL.path)")
            if !FileManager.default.fileExists(atPath: self.assetURL.path) {
                throw NSError(domain: "VideoTrimming", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Video file not found at: \(self.assetURL.path)"
                ])
            }

            let attributes = try FileManager.default.attributesOfItem(atPath: self.assetURL.path)
            let fileSize = attributes[.size] as? UInt64 ?? 0
            logger.info("Using local file for trimming. File size: \(fileSize) bytes")

            if fileSize == 0 {
                throw NSError(domain: "VideoTrimming", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Video file is empty (0 bytes)"
                ])
            }

            // Save the URL for later use
            self.localVideoURL = self.assetURL

            // Configure audio session for trimming
            logger.debug("Configuring audio session for trimming")
            self.audioSessionManager.configureForTrimming()

            // Verify that we have an incoming player with a valid item from the main app
            if let existingPlayer = playbackManager.player,
               let existingItem = existingPlayer.currentItem,
               let existingAsset = existingItem.asset as? AVURLAsset {

                logger.debug("Using existing player from app for trimming")
                let playerID = String(describing: ObjectIdentifier(existingPlayer))
                logger.debug("Using existing player ID: \(playerID)")

                // Verify the asset URL matches what was passed in
                if existingAsset.url == self.assetURL {
                    logger.debug("Player's asset URL matches expected URL: \(self.assetURL.lastPathComponent)")
                } else {
                    logger.warning("Player's asset URL doesn't match expected URL - using existing player anyway")
                    logger.warning("Expected: \(self.assetURL.lastPathComponent), Actual: \(existingAsset.url.lastPathComponent)")
                }

                // Stop any ongoing playback timer
                self.stopPlayheadUpdateTimer()

                // Store original player settings to restore later
                self.originalPlayerSettings = PlayerSettings(
                    automaticallyWaitsToMinimizeStalling: existingPlayer.automaticallyWaitsToMinimizeStalling,
                    preventsDisplaySleepDuringVideoPlayback: existingPlayer.preventsDisplaySleepDuringVideoPlayback,
                    actionAtItemEnd: existingPlayer.actionAtItemEnd
                )

                // Optimize player for trimming
                existingPlayer.pause()
                existingPlayer.automaticallyWaitsToMinimizeStalling = false
                existingPlayer.preventsDisplaySleepDuringVideoPlayback = true
                existingPlayer.actionAtItemEnd = .pause

                // Force current item status check
                if existingItem.status == .failed {
                    throw existingItem.error ?? NSError(domain: "VideoTrimming", code: 4, userInfo: [
                        NSLocalizedDescriptionKey: "Failed to use existing player - item has failed status"
                    ])
                }
            } else {
                // If we don't have a valid player, it's a critical error
                logger.error("No valid player available from main app - cannot initialize trimming view")
                throw NSError(domain: "VideoTrimming", code: 5, userInfo: [
                    NSLocalizedDescriptionKey: "Cannot access video player - try returning to main app and playing the video first"
                ])
            }

            // Force the player to begin loading and buffer some content
            logger.debug("Forcing player to begin buffering")
            playbackManager.player?.play()
            try await Task.sleep(for: .milliseconds(300))
            playbackManager.player?.pause()

            // Ensure the player is rendering the first frame correctly
            if let player = playbackManager.player {
                let currentTime = player.currentTime()
                await player.seek(to: currentTime)
                try await Task.sleep(for: .milliseconds(200))

                // Make a second attempt to ensure the player is ready
                await player.seek(to: currentTime, toleranceBefore: .zero, toleranceAfter: .zero)
            }

            // Ensure all setup is complete before marking as loaded
            // Only mark loading as complete after successful player initialization
            logger.debug("Video trim preparation complete - player is ready")
            self.isLoading = false
            self.shouldShowPlayButton = true

            // Setup notification for playback end
            if let playerItem = playbackManager.player?.currentItem {
                self.setupPlaybackEndNotification(for: playerItem)
            }

            // Seek to the start trim time
            logger.debug("Seeking to start time: \(self.startTrimTime.seconds) seconds")
            await playbackManager.player?.seek(to: self.startTrimTime, toleranceBefore: .zero, toleranceAfter: .zero)

            // Force a brief play and pause to ensure the frame is displayed
            playbackManager.player?.play()
            try await Task.sleep(for: .milliseconds(50))
            playbackManager.player?.pause()

            // Generate thumbnails in a background task to keep UI responsive
            Task {
                logger.debug("Starting thumbnail generation")
                if let asset = playbackManager.player?.currentItem?.asset {
                    self.generateThumbnails(from: asset)
                }
            }

            // Show play button
            self.shouldShowPlayButton = true

        } catch {
            logger.error("Failed to prepare trim view: \(error.localizedDescription)")
            self.error = error
            // Ensure loading state is updated even on failure
            self.isLoading = false
            self.shouldShowPlayButton = false
        }
    }
    
    /// Sets up notification for when playback reaches the end
    func setupPlaybackEndNotification(for playerItem: AVPlayerItem) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
    }
    
    /// Handler for when playback reaches the end
    @objc func playerItemDidReachEnd(notification: Notification) {
        logger.info("Video playback reached end - restarting from beginning")
        self.playbackManager.player?.seek(to: self.startTrimTime)
        self.playbackManager.player?.play()
        self.isPlaying = true
    }
    
    /// Call this before dismissing the view
    func prepareForDismissal() {
        logger.debug("🧹 TRIM_DISMISS: Starting cleanup for dismissal")

        // Stop playback and update UI state immediately
        if self.isPlaying {
            logger.debug("🧹 TRIM_DISMISS: Stopping active playback")
            playbackManager.pause()
            self.isPlaying = false
        }

        // Stop timer and ALL observers
        logger.debug("🧹 TRIM_DISMISS: Removing timers and observers")
        self.stopPlayheadUpdateTimer()

        // Remove notification observations for this object
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)

        // Clear thumbnails to release memory
        logger.debug("🧹 TRIM_DISMISS: Clearing thumbnail images")
        self.thumbnails = []

        // We don't need to clean up the player itself since it's shared,
        // but we do need to restore any settings we changed
        if let player = playbackManager.player {
            let playerID = String(describing: ObjectIdentifier(player))
            logger.debug("🧹 TRIM_DISMISS: Restoring shared player to normal state - ID: \(playerID)")

            // Pause playback
            player.pause()

            // Restore original player settings if we saved them
            if let originalSettings = self.originalPlayerSettings {
                logger.debug("🧹 TRIM_DISMISS: Restoring original player settings")
                player.automaticallyWaitsToMinimizeStalling = originalSettings.automaticallyWaitsToMinimizeStalling
                player.preventsDisplaySleepDuringVideoPlayback = originalSettings.preventsDisplaySleepDuringVideoPlayback
                player.actionAtItemEnd = originalSettings.actionAtItemEnd
            } else {
                // Fallback if we didn't save original settings
                logger.debug("🧹 TRIM_DISMISS: No original settings found, using defaults")
                player.automaticallyWaitsToMinimizeStalling = true
                player.actionAtItemEnd = .pause
            }
        }

        // Reset audio session - critically important
        logger.debug("🧹 TRIM_DISMISS: Deactivating audio session")
        self.audioSessionManager.deactivate()

        // Re-enable background services
        if Task.isCancelled == false {
            // Resume preloading service
            Task {
                let preloadService = PreloadService()
                await preloadService.resumePreloading()
                logger.debug("🧹 TRIM_DISMISS: Resumed PreloadService")
            }

            // Re-enable transition manager
            VideoTransitionManager().enableAfterTrimming()
            logger.debug("🧹 TRIM_DISMISS: Re-enabled VideoTransitionManager")

            // Reset global trim mode flag
            EnvironmentService.isInTrimMode = false
            logger.debug("🧹 TRIM_DISMISS: Reset isInTrimMode flag")
        }

        // Clean up temp files if they exist and are in temporary directory
        if let localURL = self.localVideoURL,
           !self.isSaving,
           localURL.absoluteString.contains(FileManager.default.temporaryDirectory.absoluteString) {
            do {
                logger.debug("🧹 TRIM_DISMISS: Removing temporary file at \(localURL.lastPathComponent)")
                try FileManager.default.removeItem(at: localURL)
                logger.debug("🧹 TRIM_DISMISS: Successfully removed temporary video file")
            } catch {
                logger.error("🧹 TRIM_DISMISS: Failed to delete temp file: \(error.localizedDescription)")
            }
        }

        // Release the URL reference
        self.localVideoURL = nil

        // Final cleanup report
        logger.debug("🧹 TRIM_DISMISS: Cleanup complete, player returned to normal state")
    }
}