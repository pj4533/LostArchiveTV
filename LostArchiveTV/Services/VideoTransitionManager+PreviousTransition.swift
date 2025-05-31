//
//  VideoTransitionManager+PreviousTransition.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 5/31/25.
//

import SwiftUI
import AVKit
import OSLog
import Mixpanel

// MARK: - Previous Video Transition
extension VideoTransitionManager {
    // Complete transition to the previous video (swiping DOWN)
    func completePreviousVideoTransition(
        geometry: GeometryProxy,
        provider: VideoProvider,
        dragOffset: Binding<CGFloat>,
        isDragging: Binding<Bool>,
        animationDuration: Double
    ) {
        guard prevVideoReady, let prevPlayer = prevPlayer else { return }
        
        // Track the swipe back event
        Mixpanel.mainInstance().track(event: "Swipe Back")
        
        // Update on main thread
        Task { @MainActor in
            // Mark as transitioning to prevent gesture conflicts
            isTransitioning = true
            
            // Animate transition to completion
            withAnimation(.easeOut(duration: animationDuration)) {
                dragOffset.wrappedValue = geometry.size.height  // Positive for downward movement
            }
        }
        
        // After animation completes, swap previous to current
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            // Stop old player
            provider.player?.pause()
            
            // Different handling based on provider type
            Task {
                if let viewModel = provider as? VideoPlayerViewModel {
                    // For VideoPlayerViewModel we need to call getPreviousVideo()
                    // 1. We already called it during preloadPreviousVideo()
                    // 2. But then we called getNextVideo() to reset position
                    // 3. So now we need to move the index back once more 
                    let prevVideo = await provider.getPreviousVideo()
                    
                    // Update the current cached video reference
                    if let prevVideo = prevVideo {
                        viewModel.updateCurrentCachedVideo(prevVideo)
                    }
                } else if let favoritesViewModel = provider as? FavoritesViewModel {
                    // For FavoritesViewModel, we update the index without changing the UI yet
                    // (UI will be updated by the transition manager)
                    await MainActor.run {
                        favoritesViewModel.updateToPreviousVideo()
                        
                        // Update currentVideo to match the new index
                        if favoritesViewModel.currentIndex < favoritesViewModel.favorites.count {
                            let prevVideo = favoritesViewModel.favorites[favoritesViewModel.currentIndex]
                            favoritesViewModel.setCurrentVideo(prevVideo)
                        }
                    }
                } else if let searchViewModel = provider as? SearchViewModel {
                    // For SearchViewModel, update the index similarly to FavoritesViewModel
                    await MainActor.run {
                        searchViewModel.updateToPreviousVideo()
                    }
                }
            }
            
            // Update the provider with the previous video's metadata
            provider.currentTitle = self.prevTitle
            provider.currentCollection = self.prevCollection
            provider.currentDescription = self.prevDescription
            provider.currentIdentifier = self.prevIdentifier
            provider.currentFilename = self.prevFilename

            // Also update totalFiles if supported by provider
            if let videoViewModel = provider as? BaseVideoViewModel {
                videoViewModel.totalFiles = self.prevTotalFiles
                Logger.files.info("📊 TRANSITION DOWN: Set provider.totalFiles to \(self.prevTotalFiles) for \(self.prevIdentifier)")
            }
            
            // Unmute the previous player and play it
            prevPlayer.isMuted = false
            
            // Set the previous player as current
            provider.player = prevPlayer
            
            // Play the previous video
            prevPlayer.play()
            
            // Reset animation state
            dragOffset.wrappedValue = 0
            isDragging.wrappedValue = false
            self.isTransitioning = false
            
            // Directly update the TransitionPreloadManager's previous video properties
            Task { @MainActor in
                // Reset the preload manager state
                self.preloadManager.prevVideoReady = false
                self.preloadManager.prevPlayer = nil

                // Post a notification to update UI cache status immediately
                Logger.caching.info("🔔 POSTING NOTIFICATION: CacheStatusChanged - nextVideoReady is now \(self.preloadManager.nextVideoReady)")
                NotificationCenter.default.post(name: Notification.Name("CacheStatusChanged"), object: nil)
            }
            
            // Preload in both directions and advance cache window
            Task {
                await self.handlePostTransitionCaching(provider: provider, direction: .down)
            }
        }
    }
}