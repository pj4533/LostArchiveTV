//
//  VideoTransitionManager.swift
//  LostArchiveTV
//
//  Created by Claude on 4/21/25.
//

import SwiftUI
import AVKit
import OSLog

class VideoTransitionManager: ObservableObject {
    // State tracking
    @Published var isTransitioning = false
    
    // Preload manager handles all the preloading logic
    private let preloadManager = TransitionPreloadManager()
    
    // Direction for swiping
    enum SwipeDirection {
        case up    // Swiping up shows next video
        case down  // Swiping down shows previous video
    }
    
    // Forward preload manager properties
    var nextVideoReady: Bool { preloadManager.nextVideoReady }
    var nextPlayer: AVPlayer? { preloadManager.nextPlayer }
    var nextTitle: String { preloadManager.nextTitle }
    var nextCollection: String { preloadManager.nextCollection }
    var nextDescription: String { preloadManager.nextDescription }
    var nextIdentifier: String { preloadManager.nextIdentifier }
    
    var prevVideoReady: Bool { preloadManager.prevVideoReady }
    var prevPlayer: AVPlayer? { preloadManager.prevPlayer }
    var prevTitle: String { preloadManager.prevTitle }
    var prevCollection: String { preloadManager.prevCollection }
    var prevDescription: String { preloadManager.prevDescription }
    var prevIdentifier: String { preloadManager.prevIdentifier }
    
    // MARK: - Preloading Methods
    
    func preloadNextVideo(provider: VideoProvider) async {
        await preloadManager.preloadNextVideo(provider: provider)
    }
    
    func preloadPreviousVideo(provider: VideoProvider) async {
        await preloadManager.preloadPreviousVideo(provider: provider)
    }
    
    // MARK: - Transition Methods
    
    func completeTransition(
        geometry: GeometryProxy,
        provider: VideoProvider,
        dragOffset: Binding<CGFloat>,
        isDragging: Binding<Bool>,
        animationDuration: Double,
        direction: SwipeDirection = .up
    ) {
        switch direction {
        case .up:
            // Swiping UP to see NEXT video
            completeNextVideoTransition(geometry: geometry, provider: provider, dragOffset: dragOffset, 
                                   isDragging: isDragging, animationDuration: animationDuration)
        case .down:
            // Swiping DOWN to see PREVIOUS video
            completePreviousVideoTransition(geometry: geometry, provider: provider, dragOffset: dragOffset, 
                                 isDragging: isDragging, animationDuration: animationDuration)
        }
    }
    
    // Backward compatibility method for existing code
    func completeTransition(
        geometry: GeometryProxy,
        viewModel: VideoPlayerViewModel,
        dragOffset: Binding<CGFloat>,
        isDragging: Binding<Bool>,
        animationDuration: Double,
        direction: SwipeDirection = .up
    ) {
        completeTransition(
            geometry: geometry,
            provider: viewModel,
            dragOffset: dragOffset,
            isDragging: isDragging,
            animationDuration: animationDuration,
            direction: direction
        )
    }
    
    // Complete transition to the next video (swiping UP)
    private func completeNextVideoTransition(
        geometry: GeometryProxy,
        provider: VideoProvider,
        dragOffset: Binding<CGFloat>,
        isDragging: Binding<Bool>,
        animationDuration: Double
    ) {
        guard nextVideoReady, let nextPlayer = nextPlayer else { return }
        
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
                // First, save current video to history if we're adding a new video
                // This only happens when we're at the end of history
                if provider.isAtEndOfHistory() {
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
                                name: self.nextIdentifier,
                                format: "h.264",
                                size: "",
                                length: nil
                            ),
                            videoURL: (nextPlayer.currentItem?.asset as? AVURLAsset)?.url ?? URL(string: "about:blank")!,
                            asset: (nextPlayer.currentItem?.asset as? AVURLAsset) ?? AVURLAsset(url: URL(string: "about:blank")!),
                            playerItem: nextPlayer.currentItem ?? AVPlayerItem(asset: AVURLAsset(url: URL(string: "about:blank")!)),
                            startPosition: 0
                        )
                        
                        // Add the new video to history
                        provider.addVideoToHistory(nextVideo)
                        
                        // Update the current cached video if provider is VideoPlayerViewModel
                        if let viewModel = provider as? VideoPlayerViewModel {
                            viewModel.updateCurrentCachedVideo(nextVideo)
                        }
                    }
                } else {
                    // Handle index updating and cached video tracking
                    if let viewModel = provider as? VideoPlayerViewModel {
                        // For VideoPlayerViewModel, history navigation updates the index
                        let nextVideo = await provider.getNextVideo()
                        
                        // Update the current cached video reference
                        if let nextVideo = nextVideo {
                            viewModel.updateCurrentCachedVideo(nextVideo)
                        }
                    } else if let favoritesViewModel = provider as? FavoritesViewModel {
                        // For FavoritesViewModel, we update the index without changing the UI yet
                        // (UI will be updated by the transition manager)
                        await MainActor.run {
                            favoritesViewModel.updateToNextVideo()
                        }
                    } else if let searchViewModel = provider as? SearchViewModel {
                        // For SearchViewModel, update the index similarly to FavoritesViewModel
                        await MainActor.run {
                            searchViewModel.updateToNextVideo()
                        }
                    }
                }
            }
            
            // Update the provider with the new video's metadata
            provider.currentTitle = self.nextTitle
            provider.currentCollection = self.nextCollection
            provider.currentDescription = self.nextDescription
            provider.currentIdentifier = self.nextIdentifier
            
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
            }
            
            // Preload the next videos in both directions
            Task {
                // Start filling cache to maintain videos
                await provider.ensureVideosAreCached()
                
                // Preload the next and previous videos for the UI
                await self.preloadNextVideo(provider: provider)
                await self.preloadPreviousVideo(provider: provider)
            }
        }
    }
    
    // Complete transition to the previous video (swiping DOWN)
    private func completePreviousVideoTransition(
        geometry: GeometryProxy,
        provider: VideoProvider,
        dragOffset: Binding<CGFloat>,
        isDragging: Binding<Bool>,
        animationDuration: Double
    ) {
        guard prevVideoReady, let prevPlayer = prevPlayer else { return }
        
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
            }
            
            // Preload in both directions
            Task {
                // Start filling cache to maintain videos
                await provider.ensureVideosAreCached()
                
                // Preload the next and previous videos for the UI
                await self.preloadNextVideo(provider: provider)
                await self.preloadPreviousVideo(provider: provider)
            }
        }
    }
}