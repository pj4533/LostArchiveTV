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
    /// Use the already downloaded file to initialize trim view
    func prepareForTrimming() async {
        logger.debug("prepareForTrimming started")
        isLoading = true
        
        do {
            // Verify the file exists and has content
            logger.debug("Checking file at path: \(self.assetURL.path)")
            if !FileManager.default.fileExists(atPath: self.assetURL.path) {
                logger.error("File does not exist at path: \(self.assetURL.path)")
                throw NSError(domain: "VideoTrimming", code: 5, userInfo: [
                    NSLocalizedDescriptionKey: "Downloaded file not found at: \(self.assetURL.path)"
                ])
            }
            
            let attributes = try FileManager.default.attributesOfItem(atPath: self.assetURL.path)
            let fileSize = attributes[.size] as? UInt64 ?? 0
            logger.info("Using local file for trimming. File size: \(fileSize) bytes")
            
            if fileSize == 0 {
                logger.error("File is empty (0 bytes)")
                throw NSError(domain: "VideoTrimming", code: 6, userInfo: [
                    NSLocalizedDescriptionKey: "Video file is empty (0 bytes)"
                ])
            }
            
            // Save the URL for later use
            self.localVideoURL = self.assetURL
            
            // Initialize player with the asset
            logger.debug("Creating AVAsset from URL: \(self.assetURL.absoluteString)")
            let asset = AVAsset(url: self.assetURL)
            
            // Create a new player with the asset
            logger.debug("Creating player item and player")
            playerManager.createNewPlayer(from: asset, url: self.assetURL)
            
            // Seek to the start trim time
            logger.debug("Seeking to start time: \(self.startTrimTime.seconds) seconds")
            self.seekToTime(self.startTrimTime)
            
            // Generate thumbnails
            logger.debug("Starting thumbnail generation")
            self.generateThumbnails(from: asset)
            
            // Update UI
            logger.debug("Setting isLoading = false")
            self.isLoading = false
            // Reset play button visibility
            self.shouldShowPlayButton = true
            
        } catch {
            logger.error("Failed to prepare trim view: \(error.localizedDescription)")
            self.error = error
            self.isLoading = false
        }
    }
    
    /// Call this before dismissing the view
    func prepareForDismissal() {
        logger.debug("Preparing trim view for dismissal")
        
        // First make sure playback is stopped
        if isPlaying {
            playerManager.pause()
            isPlaying = false
        }
        
        // Stop the playhead update timer
        stopPlayheadUpdateTimer()
        
        // Clean up player using PlayerManager
        playerManager.cleanupPlayer()
        
        // Reset audio session
        playerManager.deactivateAudioSession()
        
        // Clean up any downloaded temp files if not saved
        if let localURL = localVideoURL, !isSaving {
            // Only delete if it's in the temp directory
            if localURL.absoluteString.contains(FileManager.default.temporaryDirectory.absoluteString) {
                try? FileManager.default.removeItem(at: localURL)
                logger.debug("Removed temporary video file: \(localURL)")
            }
        }
        
        logger.debug("Trim view clean-up complete")
    }
}