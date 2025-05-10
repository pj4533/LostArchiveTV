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
            
            // Clean up any existing player
            if self.directPlayer != nil {
                logger.debug("Cleaning up existing player before creating a new one")
                self.directPlayer?.pause()
                self.directPlayer?.replaceCurrentItem(with: nil)
                self.stopPlayheadUpdateTimer()
                self.directPlayer = nil
                try? await Task.sleep(for: .milliseconds(100))
            }
            
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
    private func setupPlaybackEndNotification(for playerItem: AVPlayerItem) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
    }
    
    /// Handler for when playback reaches the end
    @objc private func playerItemDidReachEnd(notification: Notification) {
        logger.info("Video playback reached end - restarting from beginning")
        self.directPlayer?.seek(to: self.startTrimTime)
        self.directPlayer?.play()
        self.isPlaying = true
    }
    
    /// Call this before dismissing the view
    func prepareForDismissal() {
        logger.debug("Preparing for dismissal")
        
        // Stop playback
        if self.isPlaying {
            self.directPlayer?.pause()
            self.isPlaying = false
        }
        
        // Stop timer and observers
        self.stopPlayheadUpdateTimer()
        NotificationCenter.default.removeObserver(
            self,
            name: .AVPlayerItemDidPlayToEndTime,
            object: self.directPlayer?.currentItem
        )
        
        // Clear thumbnails
        self.thumbnails = []
        
        // Clean up player
        self.directPlayer?.pause()
        self.directPlayer?.replaceCurrentItem(with: nil)
        self.directPlayer = nil
        
        // Reset audio session
        self.audioSessionManager.deactivate()
        
        // Clean up temp files
        if let localURL = self.localVideoURL,
           !self.isSaving,
           localURL.absoluteString.contains(FileManager.default.temporaryDirectory.absoluteString) {
            do {
                try FileManager.default.removeItem(at: localURL)
                logger.debug("Removed temporary video file")
            } catch {
                logger.error("Failed to delete temp file: \(error.localizedDescription)")
            }
        }
        
        logger.debug("Cleanup complete")
    }
}