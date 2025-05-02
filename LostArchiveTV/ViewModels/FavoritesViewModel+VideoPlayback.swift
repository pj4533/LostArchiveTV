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
            try? await Task.sleep(for: .seconds(0.5))
            Logger.caching.info("Starting preload after player initialization")
            await ensureVideosAreCached()
        }
        
        isLoading = false
    }
    
    func setCurrentVideo(_ video: CachedVideo) {
        self.currentVideo = video
        
        // Update base class properties
        updateBasePropertiesFromCurrentVideo()
        
        // Create a fresh player with a new AVPlayerItem
        createAndSetupPlayer(for: video)
    }
    
    // Helper method to create a fresh player for a video
    private func createAndSetupPlayer(for video: CachedVideo) {
        Logger.caching.info("FavoritesViewModel: Creating player for video \(video.identifier)")
        
        // Clean up existing player first
        playbackManager.cleanupPlayer()
        
        // Create a fresh player item from the asset
        let freshPlayerItem = AVPlayerItem(asset: video.asset)
        let player = AVPlayer(playerItem: freshPlayerItem)
        let startTime = CMTime(seconds: video.startPosition, preferredTimescale: 600)
        
        // Seek to the correct position
        Task {
            Logger.caching.info("FavoritesViewModel: Setting up player and seeking to start position")
            await player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
            playbackManager.useExistingPlayer(player)
            playbackManager.play()
            Logger.caching.info("FavoritesViewModel: Player setup complete, playback started")
        }
    }
}