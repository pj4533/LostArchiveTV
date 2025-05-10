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
            
            // Clean up any existing player thoroughly
            if self.directPlayer != nil {
                logger.debug("Cleaning up existing player before creating a new one")
                // First stop any ongoing playback and observers
                self.directPlayer?.pause()
                self.directPlayer?.rate = 0
                self.stopPlayheadUpdateTimer()

                // Remove notification observers for this player
                NotificationCenter.default.removeObserver(
                    self,
                    name: .AVPlayerItemDidPlayToEndTime,
                    object: self.directPlayer?.currentItem
                )

                // Clear out the player item and player
                self.directPlayer?.replaceCurrentItem(with: nil)
                self.directPlayer = nil

                // Give time for resources to be released
                try? await Task.sleep(for: .milliseconds(200))
            }

            // Ensure audio session is properly configured before creating new player
            self.audioSessionManager.configureForTrimming()
            
            // Create a new player instance with robust loading
            logger.debug("Creating player for URL: \(self.assetURL.lastPathComponent)")
            let asset = AVURLAsset(url: self.assetURL)

            // Preload key asset attributes synchronously for reliable initialization
            logger.debug("Loading asset values")
            let keys = ["playable", "duration", "tracks"]
            try await asset.loadValues(forKeys: keys)

            // Verify asset is playable
            if !asset.isPlayable {
                logger.error("Asset is not playable")
                throw NSError(domain: "VideoTrimming", code: 3, userInfo: [
                    NSLocalizedDescriptionKey: "Video cannot be played - format may be unsupported"
                ])
            }

            // Create player item with explicit loadedTimeRanges observation for better loading
            let playerItem = AVPlayerItem(asset: asset)

            // Create player and configure immediately
            let player = AVPlayer(playerItem: playerItem)
            player.actionAtItemEnd = .pause
            player.volume = 1.0

            // Force pre-buffering by requesting status
            _ = try? await playerItem.asset.load(.isPlayable)

            // Verify player item is ready for playback
            if playerItem.status == .failed {
                throw playerItem.error ?? NSError(domain: "VideoTrimming", code: 4, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to load video"
                ])
            }

            // Assign player to model immediately to update UI
            self.directPlayer = player

            // Force the player to begin loading and buffer some content
            logger.debug("Forcing player to begin buffering")
            player.play()
            try await Task.sleep(for: .milliseconds(300))
            player.pause()

            // Ensure the player is rendering the first frame correctly
            let currentTime = player.currentTime()
            await player.seek(to: currentTime)
            try await Task.sleep(for: .milliseconds(200))

            // Make a second attempt to ensure the player is ready
            await player.seek(to: currentTime, toleranceBefore: .zero, toleranceAfter: .zero)

            // Update loading state early to unblock UI
            // This is critical - we must clear loading state before seeking
            self.isLoading = false
            self.shouldShowPlayButton = true
            
            // Setup notification for playback end
            self.setupPlaybackEndNotification(for: playerItem)
            
            // Seek to the start trim time
            logger.debug("Seeking to start time: \(self.startTrimTime.seconds) seconds")
            await player.seek(to: self.startTrimTime, toleranceBefore: .zero, toleranceAfter: .zero)

            // Force a brief play and pause to ensure the frame is displayed
            player.play()
            try await Task.sleep(for: .milliseconds(50))
            player.pause()

            // Generate thumbnails in a background task to keep UI responsive
            Task {
                logger.debug("Starting thumbnail generation")
                self.generateThumbnails(from: asset)
            }
            
            // Show play button
            self.shouldShowPlayButton = true
            
        } catch {
            logger.error("Failed to prepare trim view: \(error.localizedDescription)")
            self.error = error
            self.isLoading = false
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
        self.directPlayer?.seek(to: self.startTrimTime)
        self.directPlayer?.play()
        self.isPlaying = true
    }
    
    /// Call this before dismissing the view
    func prepareForDismissal() {
        logger.debug("🧹 TRIM_DISMISS: Starting comprehensive cleanup for dismissal")

        // Stop playback and update UI state immediately
        if self.isPlaying {
            logger.debug("🧹 TRIM_DISMISS: Stopping active playback")
            self.directPlayer?.pause()
            self.directPlayer?.rate = 0
            self.isPlaying = false
        }

        // Stop timer and ALL observers
        logger.debug("🧹 TRIM_DISMISS: Removing timers and observers")
        self.stopPlayheadUpdateTimer()

        // Remove all notification observations for this object
        NotificationCenter.default.removeObserver(self)

        // Clear thumbnails to release memory
        logger.debug("🧹 TRIM_DISMISS: Clearing thumbnail images")
        self.thumbnails = []

        // Perform comprehensive player cleanup
        if let player = self.directPlayer {
            let playerID = String(describing: ObjectIdentifier(player))
            logger.debug("🧹 TRIM_DISMISS: Cleaning up player - ID: \(playerID)")

            // Log player state before cleanup
            let rate = player.rate
            let currentItemStatus = player.currentItem?.status.rawValue
            logger.debug("🧹 TRIM_DISMISS: Player state before cleanup - Rate: \(rate), Item status: \(String(describing: currentItemStatus))")

            // First ensure playback is fully stopped
            player.pause()
            player.rate = 0

            // Remove the player item to release resources
            logger.debug("🧹 TRIM_DISMISS: Removing player item")
            player.replaceCurrentItem(with: nil)

            // Clear the reference
            self.directPlayer = nil
            logger.debug("🧹 TRIM_DISMISS: Player reference cleared")
        } else {
            logger.debug("🧹 TRIM_DISMISS: No player to clean up (already nil)")
        }

        // Reset audio session - critically important
        logger.debug("🧹 TRIM_DISMISS: Deactivating audio session")
        self.audioSessionManager.deactivate()

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
        logger.debug("🧹 TRIM_DISMISS: Comprehensive cleanup complete, all resources released")
    }
}