//
//  FavoritesViewModel+VideoPlayback.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import SwiftUI
import AVKit
import AVFoundation
import OSLog

// MARK: - Video Playback
extension FavoritesViewModel {
    func playVideoAt(index: Int) {
        guard index >= 0 && index < favoritesManager.favorites.count else { return }
        
        Logger.caching.info("FavoritesViewModel.playVideoAt: Playing video at index \(index)")
        isLoading = true
        currentIndex = index
        
        // Get the selected favorite
        let video = favoritesManager.favorites[index]
        
        // Set the current video reference
        self.currentVideo = video
        
        // Update base class properties
        updateBasePropertiesFromCurrentVideo()
        
        // Create a fresh player with a new AVPlayerItem
        createAndSetupPlayer(for: video)
        
        // Important: Start a task to preload videos for swiping AFTER the player is set up
        // Use a slight delay to ensure the player is fully initialized
        Task {
            // Notify that caching has started after player setup
            await cacheService.notifyCachingStarted()
            
            try? await Task.sleep(for: .seconds(0.5))
            Logger.caching.info("Starting preload after player initialization")
            await ensureVideosAreCached()
        }
        
        isLoading = false
    }
    
    func setCurrentVideo(_ video: CachedVideo) {
        // If needed, fetch most recent metadata for file info
        Task {
            do {
                // Fetch metadata for accurate file count if not already loaded
                let metadata = try await self.archiveService.fetchMetadata(for: video.identifier)
                let playableFiles = await self.archiveService.findPlayableFiles(in: metadata)

                // Count unique files
                let allVideoFiles = metadata.files.filter {
                    $0.name.hasSuffix(".mp4") ||
                    $0.format == "h.264 IA" ||
                    $0.format == "h.264" ||
                    $0.format == "MPEG4"
                }
                var uniqueBaseNames = Set<String>()
                for file in allVideoFiles {
                    let baseName = file.name.replacingOccurrences(of: "\\.mp4$", with: "", options: .regularExpression)
                    uniqueBaseNames.insert(baseName)
                }

                // Create a new video with updated count
                let updatedVideo = CachedVideo(
                    identifier: video.identifier,
                    collection: video.collection,
                    metadata: video.metadata,
                    mp4File: video.mp4File,
                    videoURL: video.videoURL,
                    asset: video.asset,
                    startPosition: video.startPosition,
                    addedToFavoritesAt: video.addedToFavoritesAt,
                    totalFiles: uniqueBaseNames.count
                )

                // Update current video
                self.currentVideo = updatedVideo

                // Update base class properties
                updateBasePropertiesFromCurrentVideo()
            } catch {
                // Use original video if metadata update fails
                self.currentVideo = video
                updateBasePropertiesFromCurrentVideo()
            }
        }

        // Create a fresh player with a new AVPlayerItem
        createAndSetupPlayer(for: video)
        
        // Notify that caching has started after player setup
        Task {
            await cacheService.notifyCachingStarted()
        }
    }
    
    // Helper method to create a fresh player for a video
    private func createAndSetupPlayer(for video: CachedVideo) {
        Logger.caching.info("FavoritesViewModel: Creating player for video \(video.identifier)")
        
        // Clean up existing player first
        playbackManager.cleanupPlayer()
        
        // Create a fresh player item from the asset
        let freshPlayerItem = AVPlayerItem(asset: video.asset)
        let player = AVPlayer(playerItem: freshPlayerItem)
        
        // Check if "start at beginning" setting is enabled
        let startAtBeginning = PlaybackPreferences.alwaysStartAtBeginning
        let startPosition = startAtBeginning ? 0.0 : video.startPosition
        let startTime = CMTime(seconds: startPosition, preferredTimescale: 600)
        
        // Seek to the correct position
        Task {
            Logger.caching.info("FavoritesViewModel: Setting up player and seeking to start position")
            await player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
            playbackManager.useExistingPlayer(player)
            // Connect the buffering monitor to the new player
            playbackManager.connectBufferingMonitor(currentBufferingMonitor)
            playbackManager.play()
            Logger.caching.info("FavoritesViewModel: Player setup complete, playback started")
        }
    }
}