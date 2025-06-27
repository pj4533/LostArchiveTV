//
//  VideoPlaybackManager+Creation.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 5/31/25.
//

import Foundation
import AVFoundation
import OSLog

// MARK: - Player Creation and Setup
extension VideoPlaybackManager {
    /// Uses an existing player instance instead of creating a new one
    func useExistingPlayer(_ player: AVPlayer) {
        let playerPointer = String(describing: ObjectIdentifier(player))
        Logger.videoPlayback.debug("🔄 PLAYER_CHANGE: Using existing player \(playerPointer) (preserving seek position)")

        // Log player item status before cleanup
        if let existingPlayer = self.player {
            let existingPointer = String(describing: ObjectIdentifier(existingPlayer))
            let existingItemStatus = existingPlayer.currentItem?.status.rawValue ?? -1
            Logger.videoPlayback.debug("🔄 PLAYER_CHANGE: About to clean up existing player \(existingPointer) with item status: \(existingItemStatus)")
        }

        // Clean up resources from the existing player WITHOUT setting player to nil
        cleanupPlayerResources()

        // Use the provided player directly
        self.player = player

        Logger.videoPlayback.debug("🔄 PLAYER_CHANGE: New player assigned \(String(describing: ObjectIdentifier(player))), current item: \(player.currentItem != nil ? "exists" : "nil")")

        // Extract and store the asset URL if it's an AVURLAsset
        if let asset = player.currentItem?.asset as? AVURLAsset {
            Logger.videoPlayback.debug("🔄 PLAYER_CHANGE: Extracted URL from asset: \(asset.url)")
            _currentVideoURL = asset.url
        } else {
            Logger.videoPlayback.warning("🔄 PLAYER_CHANGE: Could not extract URL from player asset")
        }

        // Set playback rate to 1 (normal speed)
        self.player?.rate = 1.0

        // Add time observer
        setupTimeObserver()

        // Add notification for playback ending if there's a current item
        if let playerItem = player.currentItem {
            setupPlaybackEndNotification(for: playerItem)
            Logger.videoPlayback.debug("🔄 PLAYER_CHANGE: Setup playback end notification for item status: \(playerItem.status.rawValue)")
        }

        // Get current playback position for logging
        if let currentTime = player.currentItem?.currentTime().seconds,
           let duration = player.currentItem?.duration.seconds {
            Logger.videoPlayback.info("🔄 PLAYER_CHANGE: Using player at position \(currentTime.formatted(.number.precision(.fractionLength(2))))s of \(duration.formatted(.number.precision(.fractionLength(2))))s")
        }
    }
    
    /// Creates a new player instance from an asset and URL
    func createNewPlayer(from asset: AVAsset, url: URL? = nil, startPosition: Double = 0) {
        let assetId = String(describing: ObjectIdentifier(asset))
        Logger.videoPlayback.debug("🆕 PLAYER_CREATE: Creating new player from asset \(assetId)")

        // Log player item status before cleanup
        if let existingPlayer = self.player {
            let existingPointer = String(describing: ObjectIdentifier(existingPlayer))
            let existingItemStatus = existingPlayer.currentItem?.status.rawValue ?? -1
            Logger.videoPlayback.debug("🆕 PLAYER_CREATE: About to clean up existing player \(existingPointer) with item status: \(existingItemStatus)")
        }

        // Clean up resources from the existing player
        cleanupPlayer()

        // Create a new player
        let playerItem = AVPlayerItem(asset: asset)
        Logger.videoPlayback.debug("🆕 PLAYER_CREATE: Created player item with asset \(assetId), item status: \(playerItem.status.rawValue)")

        self.player = AVPlayer(playerItem: playerItem)

        if let newPlayer = self.player {
            let newPointer = String(describing: ObjectIdentifier(newPlayer))
            Logger.videoPlayback.debug("🆕 PLAYER_CREATE: New player created with ID \(newPointer)")
        }

        // Store the URL if provided
        if let url = url {
            Logger.videoPlayback.debug("🆕 PLAYER_CREATE: Using provided URL: \(url.lastPathComponent)")
            _currentVideoURL = url
        } else if let urlAsset = asset as? AVURLAsset {
            Logger.videoPlayback.debug("🆕 PLAYER_CREATE: Extracted URL from asset: \(urlAsset.url.lastPathComponent)")
            _currentVideoURL = urlAsset.url
        }
        
        // Apply format-specific optimizations
        applyFormatSpecificOptimizations(for: asset)
        
        // Set up time observer
        setupTimeObserver()
        
        // Add notification for playback ending
        setupPlaybackEndNotification(for: playerItem)
        
        // Seek to start position if not zero
        if startPosition > 0 {
            let startTime = CMTime(seconds: startPosition, preferredTimescale: 600)
            player?.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }
    
    private func applyFormatSpecificOptimizations(for asset: AVAsset) {
        // Detect the format from URL if possible
        var fileFormat = "unknown"
        var isH264 = false
        var isH264IA = false
        
        if let urlAsset = asset as? AVURLAsset {
            // Try to extract format from URL path components
            let urlPath = urlAsset.url.path.lowercased()
            
            // Update format information for logging
            if urlPath.contains("h.264") && urlPath.contains("ia") {
                fileFormat = "h.264 IA"
                isH264 = true
                isH264IA = true
            } else if urlPath.contains("h.264") || urlPath.contains("h264") {
                fileFormat = "h.264"
                isH264 = true
            } else {
                fileFormat = "MPEG4"
            }
            
            Logger.videoPlayback.info("Player setup with format-specific optimizations for: \(fileFormat)")
        }
        
        // Apply format-specific player settings
        if isH264IA {
            // h.264 IA specific player optimizations
            Logger.videoPlayback.debug("Applying h.264 IA specific player settings")
            // For h.264 IA, we can disable waiting to minimize stalling since it's optimized for streaming
            player?.automaticallyWaitsToMinimizeStalling = false
        } else if isH264 {
            // Regular h.264 optimizations - keep auto stalling for smoother playback
            Logger.videoPlayback.debug("Applying regular h.264 player settings")
            player?.automaticallyWaitsToMinimizeStalling = true
        } else {
            // MPEG4 - definitely need auto stalling
            Logger.videoPlayback.debug("Applying MPEG4 player settings")
            player?.automaticallyWaitsToMinimizeStalling = true
        }
    }
}