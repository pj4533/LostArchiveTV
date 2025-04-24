//
//  VideoTransitionManager.swift
//  LostArchiveTV
//
//  Created by Claude on 4/21/25.
//

import SwiftUI
import AVKit
import OSLog

// Protocol for view models that can provide videos for the transition manager
protocol VideoProvider: AnyObject {
    // Get the next video in the sequence
    func getNextVideo() async -> CachedVideo?
    
    // Get the previous video in the sequence
    func getPreviousVideo() async -> CachedVideo?
    
    // Check if we're at the end of the sequence
    func isAtEndOfHistory() -> Bool
    
    // Create a cached video from the current state
    func createCachedVideoFromCurrentState() async -> CachedVideo?
    
    // Add a video to the sequence
    func addVideoToHistory(_ video: CachedVideo)
    
    // Current video properties
    var player: AVPlayer? { get set }
    var currentIdentifier: String? { get set }
    var currentTitle: String? { get set }
    var currentCollection: String? { get set }
    var currentDescription: String? { get set }
    
    // Ensure videos are preloaded/cached
    func ensureVideosAreCached() async
}

class VideoTransitionManager: ObservableObject {
    // State tracking
    @Published var isTransitioning = false
    
    // Next (down) video properties
    @Published var nextVideoReady = false
    @Published var nextPlayer: AVPlayer?
    @Published var nextTitle: String = ""
    @Published var nextCollection: String = ""
    @Published var nextDescription: String = ""
    @Published var nextIdentifier: String = ""
    
    // Previous (up) video properties
    @Published var prevVideoReady = false
    @Published var prevPlayer: AVPlayer?
    @Published var prevTitle: String = ""
    @Published var prevCollection: String = ""
    @Published var prevDescription: String = ""
    @Published var prevIdentifier: String = ""
    
    // Preload the next video while current one is playing
    func preloadNextVideo(provider: VideoProvider) async {
        // Reset next video ready flag
        await MainActor.run {
            nextVideoReady = false
        }
        
        // First check if we have a next video in history/sequence
        if let nextVideo = await provider.getNextVideo() {
            // Move back to current position (getNextVideo moved us forward)
            // We'll move forward again when the transition actually happens
            _ = await provider.getPreviousVideo()
            
            // Create a new player with a fresh player item
            let freshPlayerItem = AVPlayerItem(asset: nextVideo.asset)
            let player = AVPlayer(playerItem: freshPlayerItem)
            
            // Prepare player but keep it paused and muted
            player.isMuted = true
            player.pause()
            
            // Seek to the start position
            let startTime = CMTime(seconds: nextVideo.startPosition, preferredTimescale: 600)
            await player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
            
            // Update UI on main thread
            await MainActor.run {
                // Update next video metadata
                nextTitle = nextVideo.title
                nextCollection = nextVideo.collection
                nextDescription = nextVideo.description
                nextIdentifier = nextVideo.identifier
                
                // Store reference to next player
                nextPlayer = player
                
                // Mark next video as ready
                nextVideoReady = true
            }
            
            Logger.caching.info("Successfully prepared next video: \(nextVideo.identifier)")
            return
        }
        
        // For VideoPlayerViewModel, we can try to load a new random video
        // For FavoritesViewModel, check if we have reached the end
        if let videoPlayerViewModel = provider as? VideoPlayerViewModel {
            // If we don't have a next video in history, get a new random video
            let service = VideoLoadingService(
                archiveService: videoPlayerViewModel.archiveService,
                cacheManager: videoPlayerViewModel.cacheManager
            )
            
            do {
                // Load a complete random video
                let videoInfo = try await service.loadRandomVideo()
                
                // Create a new player for the asset
                let freshPlayerItem = AVPlayerItem(asset: videoInfo.asset)
                let player = AVPlayer(playerItem: freshPlayerItem)
                
                // Prepare player but keep it paused and muted
                player.isMuted = true
                player.pause()
                
                // Seek to the start position
                let startTime = CMTime(seconds: videoInfo.startPosition, preferredTimescale: 600)
                await player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
                
                // Update UI on main thread
                await MainActor.run {
                    // Update next video metadata
                    nextTitle = videoInfo.title
                    nextCollection = videoInfo.collection
                    nextDescription = videoInfo.description
                    nextIdentifier = videoInfo.identifier
                    
                    // Store reference to next player
                    nextPlayer = player
                    
                    // Mark next video as ready
                    nextVideoReady = true
                }
                
                Logger.caching.info("Successfully preloaded new random video: \(videoInfo.identifier)")
            } catch {
                // Retry on error after a short delay
                Logger.caching.error("Failed to preload random video: \(error.localizedDescription)")
                try? await Task.sleep(for: .seconds(0.5))
                await preloadNextVideo(provider: provider)
            }
        } else if let favoritesViewModel = provider as? FavoritesViewModel {
            // For favorites view, check if we still have favorites in the list
            let favorites = await MainActor.run { favoritesViewModel.favorites }
            
            // If we have more than one favorite, circularly navigate to enable looping
            if favorites.count > 1 {
                // We can always loop around in favorites
                if let nextVideo = await provider.getNextVideo() {
                    // Create a new player for the asset
                    let freshPlayerItem = AVPlayerItem(asset: nextVideo.asset)
                    let player = AVPlayer(playerItem: freshPlayerItem)
                    
                    // Prepare player but keep it paused and muted
                    player.isMuted = true
                    player.pause()
                    
                    // Seek to the start position
                    let startTime = CMTime(seconds: nextVideo.startPosition, preferredTimescale: 600)
                    await player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
                    
                    // Update UI on main thread
                    await MainActor.run {
                        // Update next video metadata
                        nextTitle = nextVideo.title
                        nextCollection = nextVideo.collection ?? ""
                        nextDescription = nextVideo.description
                        nextIdentifier = nextVideo.identifier
                        
                        // Store reference to next player
                        nextPlayer = player
                        
                        // Mark next video as ready
                        nextVideoReady = true
                    }
                    
                    Logger.caching.info("Successfully preloaded next favorite video: \(nextVideo.identifier)")
                }
            } else {
                // If only one favorite exists, don't enable swiping
                Logger.caching.info("Only one favorite video found, not marking as ready")
            }
        } else {
            // Unknown provider type
            Logger.caching.warning("Unknown provider type for preloading")
        }
    }
    
    // Preload the previous video from history/sequence
    func preloadPreviousVideo(provider: VideoProvider) async {
        // Reset previous video ready flag
        await MainActor.run {
            prevVideoReady = false
        }
        
        // For all providers, check if there's a previous video directly available
        if let previousVideo = await provider.getPreviousVideo() {
            // For normal providers that change state during getPreviousVideo, move back to original position
            if provider is VideoPlayerViewModel {
                // Move back to current index (getPreviousVideo moved us backward)
                // We'll move backward again when the transition actually happens
                _ = await provider.getNextVideo()
            }
            
            // Create a new player for the asset
            let freshPlayerItem = AVPlayerItem(asset: previousVideo.asset)
            let player = AVPlayer(playerItem: freshPlayerItem)
            
            // Prepare player but keep it paused and muted
            player.isMuted = true
            player.pause()
            
            // Seek to the start position
            let startTime = CMTime(seconds: previousVideo.startPosition, preferredTimescale: 600)
            await player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
            
            // Update UI on main thread
            await MainActor.run {
                // Update previous video metadata
                prevTitle = previousVideo.title
                prevCollection = previousVideo.collection ?? ""
                prevDescription = previousVideo.description
                prevIdentifier = previousVideo.identifier
                
                // Store reference to previous player
                prevPlayer = player
                
                // Mark previous video as ready
                prevVideoReady = true
            }
            
            Logger.caching.info("Successfully prepared previous video: \(previousVideo.identifier)")
            return
        } 
        
        // Special handling for FavoritesViewModel
        if let favoritesViewModel = provider as? FavoritesViewModel {
            // For favorites view, check if we still have favorites in the list
            let favorites = await MainActor.run { favoritesViewModel.favorites }
            
            // If we have more than one favorite, circularly navigate to enable looping
            if favorites.count > 1 {
                // We should have been able to get a previous video above, so if we reached here, something's wrong
                Logger.caching.warning("Failed to preload previous favorite video")
            } else {
                // If only one favorite exists, don't enable swiping
                Logger.caching.info("Only one favorite video found, not marking previous as ready")
            }
        } else {
            Logger.caching.warning("No previous video available in sequence")
        }
    }
    
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
    
    // Direction for swiping
    enum SwipeDirection {
        case up    // Swiping up shows next video
        case down  // Swiping down shows previous video
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
            self.nextVideoReady = false
            self.nextPlayer = nil
            
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
            self.prevVideoReady = false
            self.prevPlayer = nil
            
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