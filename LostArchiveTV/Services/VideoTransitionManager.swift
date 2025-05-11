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

    // Flag to track if preloading is paused
    private var isPreloadingPaused = false
    
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
    var nextFilename: String { preloadManager.nextFilename }
    var nextTotalFiles: Int { preloadManager.nextTotalFiles }

    var prevVideoReady: Bool { preloadManager.prevVideoReady }
    var prevPlayer: AVPlayer? { preloadManager.prevPlayer }
    var prevTitle: String { preloadManager.prevTitle }
    var prevCollection: String { preloadManager.prevCollection }
    var prevDescription: String { preloadManager.prevDescription }
    var prevIdentifier: String { preloadManager.prevIdentifier }
    var prevFilename: String { preloadManager.prevFilename }
    var prevTotalFiles: Int { preloadManager.prevTotalFiles }
    
    // MARK: - Preloading Methods
    
    func preloadNextVideo(provider: VideoProvider) async {
        // Skip if preloading is paused
        guard !isPreloadingPaused else {
            Logger.caching.info("⏸️ SKIPPED: preloadNextVideo called while preloading is paused")
            return
        }

        await preloadManager.preloadNextVideo(provider: provider)
    }

    func preloadPreviousVideo(provider: VideoProvider) async {
        // Skip if preloading is paused
        guard !isPreloadingPaused else {
            Logger.caching.info("⏸️ SKIPPED: preloadPreviousVideo called while preloading is paused")
            return
        }

        await preloadManager.preloadPreviousVideo(provider: provider)
    }
    
    /// Ensures that both general video caching and transition-specific caching are performed
    /// - Parameter provider: The video provider that supplies videos
    func ensureAllVideosCached(provider: VideoProvider) async {
        // Skip if preloading is paused
        guard !isPreloadingPaused else {
            Logger.caching.info("⏸️ SKIPPED: ensureAllVideosCached called while preloading is paused")
            return
        }

        // Delegate to the underlying preload manager for unified caching
        await preloadManager.ensureAllVideosCached(provider: provider)
    }

    /// Pauses all preloading and caching operations
    func pausePreloading() {
        Logger.caching.info("⏸️ PAUSE: Pausing all transition preloading operations")
        isPreloadingPaused = true
    }

    /// Resumes all preloading and caching operations
    func resumePreloading() {
        Logger.caching.info("▶️ RESUME: Resuming all transition preloading operations")
        isPreloadingPaused = false
    }

    /// Disables transition manager during trim mode
    func disableForTrimming() {
        Logger.caching.info("⏸️ TRIM: Disabling VideoTransitionManager for trim mode")
        pausePreloading()
    }

    /// Restores transition manager after trim mode
    func enableAfterTrimming() {
        Logger.caching.info("▶️ TRIM: Re-enabling VideoTransitionManager after trim mode")
        resumePreloading()
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
        // Add logging of the transition operation
        let directionText = direction == .up ? "UP (next)" : "DOWN (previous)"
        Logger.caching.info("🔄 TRANSITION: Starting \(directionText) transition with provider: \(type(of: provider))")
        
        if let providerVideo = provider.currentIdentifier {
            Logger.caching.info("🎬 TRANSITION: Current video: \(providerVideo)")
        }
        
        // Get cache state during transition
        Task {
            if let cacheProvider = provider as? CacheableProvider {
                let cacheCount = await cacheProvider.cacheManager.cacheCount()
                Logger.caching.info("📊 TRANSITION: Cache size at transition start: \(cacheCount)")
            }
        }
        
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

                // Post a notification to update UI cache status immediately
                Logger.caching.info("🔔 POSTING NOTIFICATION: CacheStatusChanged - nextVideoReady is now \(self.preloadManager.nextVideoReady)")
                NotificationCenter.default.post(name: Notification.Name("CacheStatusChanged"), object: nil)
            }
            
            // Preload the next videos in both directions and advance cache window
            Task {
                // Create a cached video from the current preloaded video first
                if let cacheableProvider = provider as? CacheableProvider {
                    // CRITICAL: Signal that preloading is starting BEFORE we modify the cache
                    // This ensures NO caching operations interfere with preloading
                    await cacheableProvider.cacheService.setPreloadingStarted()
                    Logger.caching.info("🚦 TRANSITION: Signaled preloading started to halt caching BEFORE cache operations")

                    // Get cache state before any operations
                    let cacheCount = await cacheableProvider.cacheManager.cacheCount()
                    Logger.caching.info("📊 TRANSITION: Initial cache count: \(cacheCount)")

                    // This is the key part - ensure the current video is in the cache
                    // since it was previously outside the cache as a preloaded video
                    if let currentVideo = await provider.createCachedVideoFromCurrentState() {
                        Logger.caching.info("🧹 TRANSITION: Removing current video from cache if it exists: \(currentVideo.identifier)")
                        await cacheableProvider.cacheManager.removeVideo(identifier: currentVideo.identifier)
                    }

                    // Skip cache window advancement during transition
                    // We'll do this after preloading is complete instead
                    Logger.caching.info("🔄 TRANSITION: Skipping cache advancement until preloading completes")
                } else {
                    // Fallback for non-cacheable providers
                    Logger.caching.info("🔄 TRANSITION: Provider doesn't support sliding window, using regular cache filling")
                    await provider.ensureVideosAreCached()
                }

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
                Logger.caching.info("📢 TRANSITION COMPLETE: Starting cache advancement after DOWN transition")

                // Advance the cache window using our new sliding window approach
                if let cacheableProvider = provider as? CacheableProvider {
                    // CRITICAL: Signal that preloading is starting BEFORE we modify the cache
                    // This ensures NO caching operations interfere with preloading
                    await cacheableProvider.cacheService.setPreloadingStarted()
                    Logger.caching.info("🚦 TRANSITION: Signaled preloading started to halt caching BEFORE cache operations")

                    // Check initial cache state
                    let initialCacheCount = await cacheableProvider.cacheManager.cacheCount()
                    Logger.caching.info("📊 TRANSITION COMPLETE: Cache size before advancement: \(initialCacheCount)")

                    // This is the key part - ensure the current video is in the cache
                    // since it was previously outside the cache as a preloaded video
                    if let currentVideo = await provider.createCachedVideoFromCurrentState() {
                        Logger.caching.info("🧹 TRANSITION: Removing current video from cache if it exists: \(currentVideo.identifier)")
                        await cacheableProvider.cacheManager.removeVideo(identifier: currentVideo.identifier)
                    }

                    // Skip cache window advancement during transition
                    // We'll do this after preloading is complete instead
                    Logger.caching.info("🔄 TRANSITION: Skipping cache advancement until preloading completes")
                } else {
                    // Fallback for non-cacheable providers
                    Logger.caching.info("🔄 TRANSITION: Provider doesn't support sliding window, using regular cache filling")
                    await provider.ensureVideosAreCached()
                }

                // Preload the next and previous videos for the UI
                Logger.caching.info("🔄 TRANSITION COMPLETE: Preloading next/previous videos for UI")
                await self.preloadNextVideo(provider: provider)
                await self.preloadPreviousVideo(provider: provider)
                Logger.caching.info("✅ TRANSITION COMPLETE: Done preloading videos for UI")
            }
        }
    }
}