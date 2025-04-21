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
    @Published var nextVideoReady = false
    @Published var isTransitioning = false
    @Published var nextPlayer: AVPlayer?
    @Published var nextTitle: String = ""
    @Published var nextCollection: String = ""
    @Published var nextDescription: String = ""
    @Published var nextIdentifier: String = ""
    
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
    
    func completeTransition(
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
                dragOffset.wrappedValue = geometry.size.height
            }
        }
        
        // After animation completes, swap next to current
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            // Stop old player
            viewModel.player?.pause()
            
            // Save the previous identifier to remove from cache
            let previousIdentifier = viewModel.currentIdentifier
            
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
            
            // Simple logic: 1) Remove viewed video from cache, 2) Add new video to cache, 3) Preload next UI video
            Task {
                // Step 1: Remove the viewed video from cache
                if let prevId = previousIdentifier {
                    Logger.caching.info("Removing viewed video \(prevId) from cache")
                    await viewModel.cacheManager.removeVideo(identifier: prevId)
                }
                
                // Step 2: Start filling cache to maintain 3 videos
                await viewModel.ensureVideosAreCached()
                
                // Step 3: Preload the next video for the UI
                await self.preloadNextVideo(viewModel: viewModel)
            }
        }
    }
}