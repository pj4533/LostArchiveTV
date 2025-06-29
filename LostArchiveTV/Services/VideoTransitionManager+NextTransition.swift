//
//  VideoTransitionManager+NextTransition.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 5/31/25.
//

import SwiftUI
import AVKit
import OSLog
import Mixpanel
import Combine

// MARK: - Next Video Transition
extension VideoTransitionManager {
    // Complete transition to the next video (swiping UP)
    func completeNextVideoTransition(
        geometry: GeometryProxy,
        provider: VideoProvider,
        dragOffset: Binding<CGFloat>,
        isDragging: Binding<Bool>,
        animationDuration: Double
    ) {
        // Check buffer readiness using the buffer state
        guard preloadManager.currentNextBufferState.isReady, let nextPlayer = nextPlayer else {
            Logger.caching.info("⚠️ TRANSITION: Cannot complete next transition - buffer not ready (\(self.preloadManager.currentNextBufferState.description)) or player nil")
            return
        }
        
        // Track the swipe next event
        Mixpanel.mainInstance().track(event: "Swipe Next")
        
        // Update on main thread
        Task { @MainActor in
            // Mark as transitioning to prevent gesture conflicts
            isTransitioning = true
            
            // Animate transition to completion
            withAnimation(.easeOut(duration: animationDuration)) {
                dragOffset.wrappedValue = -geometry.size.height  // Negative for upward movement
            }
        }
        
        // After animation completes, swap next to current
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            // Stop old player
            provider.player?.pause()
            
            // Handle forward navigation
            Task {
                // CRITICAL FIX: First check if we have a next video in history
                // using peekNextVideo to not change the current index
                if let existingNextVideo = await provider.peekNextVideo() {
                    Logger.caching.info("📊 TRANSITION: Found existing next video in history: \(existingNextVideo.identifier)")

                    // Handle index updating and cached video tracking
                    if let viewModel = provider as? VideoPlayerViewModel {
                        // For VideoPlayerViewModel, history navigation updates the index
                        let nextVideo = await provider.getNextVideo()

                        // Update the current cached video reference
                        if let nextVideo = nextVideo {
                            viewModel.updateCurrentCachedVideo(nextVideo)
                            Logger.caching.info("📊 TRANSITION: Updated to existing video from history: \(nextVideo.identifier)")
                        }
                    } else if let favoritesViewModel = provider as? FavoritesViewModel {
                        // For FavoritesViewModel, we update the index without changing the UI yet
                        // (UI will be updated by the transition manager)
                        await MainActor.run {
                            favoritesViewModel.updateToNextVideo()

                            // Update currentVideo to match the new index
                            if favoritesViewModel.currentIndex < favoritesViewModel.favorites.count {
                                let nextVideo = favoritesViewModel.favorites[favoritesViewModel.currentIndex]
                                favoritesViewModel.setCurrentVideo(nextVideo)
                            }
                        }
                    } else if let searchViewModel = provider as? SearchViewModel {
                        // For SearchViewModel, update the index similarly to FavoritesViewModel
                        await MainActor.run {
                            searchViewModel.updateToNextVideo()
                        }
                    }
                } else if provider.isAtEndOfHistory() {
                    // We need to add a new video to history only if we're at the end
                    // and don't have a next video yet
                    Logger.caching.info("📊 TRANSITION: At end of history, adding new videos")

                    // Create a cached video from current state
                    if let currentVideo = await provider.createCachedVideoFromCurrentState() {
                        // Add to history first
                        provider.addVideoToHistory(currentVideo)

                        // Then create a new cached video for the next one
                        let nextVideo = CachedVideo(
                            identifier: self.nextIdentifier,
                            collection: self.nextCollection,
                            metadata: ArchiveMetadata(
                                files: [],
                                metadata: ItemMetadata(
                                    identifier: self.nextIdentifier,
                                    title: self.nextTitle,
                                    description: self.nextDescription
                                )
                            ),
                            mp4File: ArchiveFile(
                                name: self.nextFilename,
                                format: "h.264",
                                size: "",
                                length: nil
                            ),
                            videoURL: (nextPlayer.currentItem?.asset as? AVURLAsset)?.url ?? URL(string: "about:blank")!,
                            asset: (nextPlayer.currentItem?.asset as? AVURLAsset) ?? AVURLAsset(url: URL(string: "about:blank")!),
                            playerItem: nextPlayer.currentItem ?? AVPlayerItem(asset: AVURLAsset(url: URL(string: "about:blank")!)),
                            startPosition: 0,
                            addedToFavoritesAt: nil,
                            totalFiles: self.nextTotalFiles
                        )

                        Logger.files.info("📊 TRANSITION: Creating new CachedVideo with totalFiles: \(self.nextTotalFiles) for \(self.nextIdentifier)")

                        // Add the new video to history
                        provider.addVideoToHistory(nextVideo)

                        // Update the current cached video if provider is VideoPlayerViewModel
                        if let viewModel = provider as? VideoPlayerViewModel {
                            viewModel.updateCurrentCachedVideo(nextVideo)
                            Logger.caching.info("📊 TRANSITION: Added brand new video to history: \(nextVideo.identifier)")
                        }
                    }
                } else {
                    // This is a fallback case that shouldn't normally happen
                    // It means we're not at the end of history but also don't have a next video
                    Logger.caching.error("⚠️ TRANSITION: Unexpected state - not at end of history but no next video found")
                }
            }
            
            // Update the provider with the new video's metadata
            provider.currentTitle = self.nextTitle
            provider.currentCollection = self.nextCollection
            provider.currentDescription = self.nextDescription
            provider.currentIdentifier = self.nextIdentifier
            provider.currentFilename = self.nextFilename

            // Also update totalFiles if supported by provider
            if let videoViewModel = provider as? BaseVideoViewModel {
                videoViewModel.totalFiles = self.nextTotalFiles
                Logger.files.info("📊 TRANSITION UP: Set provider.totalFiles to \(self.nextTotalFiles) for \(self.nextIdentifier)")
            }
            
            // Unmute the new player and play it
            nextPlayer.isMuted = false
            
            // Set the new player as current
            provider.player = nextPlayer
            
            // Play the new current video
            nextPlayer.play()
            
            // Reset animation state
            dragOffset.wrappedValue = 0
            isDragging.wrappedValue = false
            self.isTransitioning = false
            
            // Directly update the TransitionPreloadManager's next video properties
            Task { @MainActor in
                // Reset the preload manager state
                self.preloadManager.nextVideoReady = false
                self.preloadManager.nextPlayer = nil

                // Post a notification to update UI buffer status immediately
                Logger.caching.info("🔔 POSTING NOTIFICATION: BufferStatusChanged - nextVideoReady is now \(self.preloadManager.nextVideoReady)")
                // When clearing next player, reset buffer state to unknown
                self.preloadManager.updateNextBufferState(.unknown)
            }
            
            // Preload the next videos in both directions and advance cache window
            Task {
                await self.handlePostTransitionCaching(provider: provider, direction: .up)
            }
        }
    }
}