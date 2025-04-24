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
    func preloadNextVideo(viewModel: VideoPlayerViewModel) async {
        // Reset next video ready flag
        await MainActor.run {
            nextVideoReady = false
        }
        
        // Create a temporary loading service to load next video
        let service = VideoLoadingService(
            archiveService: viewModel.archiveService,
            cacheManager: viewModel.cacheManager
        )
        
        do {
            // Load a complete random video
            let videoInfo = try await service.loadRandomVideo()
            
            // Create a new player for the asset
            let player = AVPlayer(playerItem: AVPlayerItem(asset: videoInfo.asset))
            
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
        } catch {
            // Retry on error after a short delay
            try? await Task.sleep(for: .seconds(0.5))
            await preloadNextVideo(viewModel: viewModel)
        }
    }
    
    // Preload the previous video from history
    func preloadPreviousVideo(viewModel: VideoPlayerViewModel) async {
        // Reset previous video ready flag
        await MainActor.run {
            prevVideoReady = false
        }
        
        // Get previous video from history
        guard let previousVideo = await viewModel.getPreviousVideo() else {
            Logger.caching.warning("No previous video available in history")
            return
        }
        
        do {
            // Create a new player for the asset
            let player = AVPlayer(playerItem: AVPlayerItem(asset: previousVideo.asset))
            
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
                prevCollection = previousVideo.collection
                prevDescription = previousVideo.description
                prevIdentifier = previousVideo.identifier
                
                // Store reference to previous player
                prevPlayer = player
                
                // Mark previous video as ready
                prevVideoReady = true
            }
            
            Logger.caching.info("Successfully preloaded previous video: \(previousVideo.identifier)")
        } catch {
            Logger.caching.error("Failed to preload previous video: \(error.localizedDescription)")
        }
    }
    
    func completeTransition(
        geometry: GeometryProxy,
        viewModel: VideoPlayerViewModel,
        dragOffset: Binding<CGFloat>,
        isDragging: Binding<Bool>,
        animationDuration: Double,
        direction: SwipeDirection = .up
    ) {
        switch direction {
        case .up:
            // Swiping UP to see NEXT video
            completeNextVideoTransition(geometry: geometry, viewModel: viewModel, dragOffset: dragOffset, 
                                   isDragging: isDragging, animationDuration: animationDuration)
        case .down:
            // Swiping DOWN to see PREVIOUS video
            completePreviousVideoTransition(geometry: geometry, viewModel: viewModel, dragOffset: dragOffset, 
                                 isDragging: isDragging, animationDuration: animationDuration)
        }
    }
    
    // Direction for swiping
    enum SwipeDirection {
        case up    // Swiping up shows next video
        case down  // Swiping down shows previous video
    }
    
    // Complete transition to the next video (swiping UP)
    private func completeNextVideoTransition(
        geometry: GeometryProxy,
        viewModel: VideoPlayerViewModel,
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
            viewModel.player?.pause()
            
            // Save current video to history if needed
            Task {
                if let currentVideo = await viewModel.createCachedVideoFromCurrentState() {
                    viewModel.addVideoToHistory(currentVideo)
                }
            }
            
            // Update the view model with the new video's metadata
            viewModel.currentTitle = self.nextTitle
            viewModel.currentCollection = self.nextCollection
            viewModel.currentDescription = self.nextDescription
            viewModel.currentIdentifier = self.nextIdentifier
            
            // Unmute the new player and play it
            nextPlayer.isMuted = false
            
            // Set the new player as current
            viewModel.player = nextPlayer
            
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
                await viewModel.ensureVideosAreCached()
                
                // Preload the next and previous videos for the UI
                await self.preloadNextVideo(viewModel: viewModel)
                await self.preloadPreviousVideo(viewModel: viewModel)
            }
        }
    }
    
    // Complete transition to the previous video (swiping DOWN)
    private func completePreviousVideoTransition(
        geometry: GeometryProxy,
        viewModel: VideoPlayerViewModel,
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
            viewModel.player?.pause()
            
            // Update the view model with the previous video's metadata
            viewModel.currentTitle = self.prevTitle
            viewModel.currentCollection = self.prevCollection
            viewModel.currentDescription = self.prevDescription
            viewModel.currentIdentifier = self.prevIdentifier
            
            // Unmute the previous player and play it
            prevPlayer.isMuted = false
            
            // Set the previous player as current
            viewModel.player = prevPlayer
            
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
                await viewModel.ensureVideosAreCached()
                
                // Preload the next and previous videos for the UI
                await self.preloadNextVideo(viewModel: viewModel)
                await self.preloadPreviousVideo(viewModel: viewModel)
            }
        }
    }
}