//
//  SwipeableVideoView.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import SwiftUI
import AVKit
import OSLog

struct SwipeableVideoView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var isTransitioning = false
    @State private var nextVideoReady = false
    @State private var nextPlayer: AVPlayer?
    @State private var nextTitle: String = ""
    @State private var nextCollection: String = ""
    @State private var nextDescription: String = ""
    @State private var nextIdentifier: String = ""
    
    // Constants for animation
    private let swipeThreshold: CGFloat = 100
    private let animationDuration = 0.3
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Black background
                Color.black.ignoresSafeArea()
                
                // Next video positioned below current video
                if let nextPlayer = nextPlayer, nextVideoReady {
                    ZStack {
                        // Next video content
                        VideoPlayerContent(
                            player: nextPlayer,
                            viewModel: viewModel
                        )
                        
                        // Next video info
                        VideoInfoOverlay(
                            title: nextTitle,
                            collection: nextCollection,
                            description: nextDescription,
                            identifier: nextIdentifier
                        )
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    // Position below current view, moves up as current view moves up
                    .offset(y: geometry.size.height - dragOffset)
                }
                
                // Current video
                if viewModel.isLoading && nextPlayer == nil {
                    // Show loading screen only for initial load
                    LoadingView()
                } else if let error = viewModel.errorMessage {
                    // Show error screen when there's an error
                    ErrorView(error: error) {
                        Task {
                            await preloadNextVideo()
                        }
                    }
                } else if let player = viewModel.player {
                    // Show the current video when available
                    ZStack {
                        // Current video content - moves up with swipe
                        VideoPlayerContent(
                            player: player,
                            viewModel: viewModel
                        )
                        .offset(y: -dragOffset)  // Move up as user swipes up
                        
                        // Bottom video info - moves with video
                        VideoInfoOverlay(
                            title: viewModel.currentTitle,
                            collection: viewModel.currentCollection,
                            description: viewModel.currentDescription,
                            identifier: viewModel.currentIdentifier
                        )
                        .offset(y: -dragOffset)
                    }
                } else {
                    // Fallback if player isn't loaded yet but not in loading state
                    LoadingView()
                    
                    // Auto-trigger video load if needed
                    .onAppear {
                        if !viewModel.isLoading {
                            Task {
                                await viewModel.loadRandomVideo()
                                await preloadNextVideo()
                            }
                        }
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            // Gesture for vertical swipe - only enable when we have a video playing and next video is ready
            .gesture(
                viewModel.player == nil || viewModel.isLoading || !nextVideoReady ? nil :
                    DragGesture()
                    .onChanged { value in
                        guard !isTransitioning else { return }
                        
                        let translation = value.translation.height
                        isDragging = true
                        // Only allow upward swipes (negative translation values)
                        if translation < 0 {
                            // Convert negative translation to positive offset
                            dragOffset = min(-translation, geometry.size.height)
                        } else {
                            // Allow slight bounce-back but with resistance
                            dragOffset = 0
                        }
                    }
                    .onEnded { value in
                        guard !isTransitioning && dragOffset > 0 else {
                            // If we're not actually dragging up, just reset
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                dragOffset = 0
                                isDragging = false
                            }
                            return
                        }
                        
                        let translation = value.translation.height
                        let velocity = value.predictedEndTranslation.height - value.translation.height
                        
                        // Determine if swipe should complete based on threshold or velocity
                        let shouldComplete = -translation > swipeThreshold || -velocity > 500
                        
                        if shouldComplete {
                            // Complete the swipe animation upward
                            completeTransition(geometry: geometry)
                        } else {
                            // Bounce back to original position
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                dragOffset = 0
                                isDragging = false
                            }
                        }
                    }
            )
            .onAppear {
                // Ensure we have a video loaded and the next video is ready
                if viewModel.player == nil && !viewModel.isLoading {
                    Task {
                        Logger.caching.info("SwipeableVideoView: No video loaded, loading first video")
                        await viewModel.loadRandomVideo()
                        
                        // Ensure next video is preloaded for swiping
                        if !nextVideoReady {
                            Logger.caching.info("SwipeableVideoView: Preloading next video for swiping")
                            await preloadNextVideo()
                        }
                    }
                } else if viewModel.player != nil && !nextVideoReady {
                    // Preload next video if we already have current video but no next video ready
                    Task {
                        Logger.caching.info("SwipeableVideoView: Current video loaded but next video not ready, preloading now")
                        await preloadNextVideo()
                    }
                } else {
                    Logger.caching.info("SwipeableVideoView: Video playing and next video ready")
                }
            }
        }
    }
    
    // Preload the next video while current one is playing
    private func preloadNextVideo() async {
        // Reset next video ready flag
        nextVideoReady = false
        
        // Create a temporary loading service to load next video
        let service = VideoLoadingService(
            archiveService: viewModel.archiveService,
            cacheManager: viewModel.cacheManager
        )
        
        do {
            // Load a complete random video
            let videoInfo = try await service.loadRandomVideo()
            
            // Update next video metadata
            nextTitle = videoInfo.title
            nextCollection = videoInfo.collection
            nextDescription = videoInfo.description
            nextIdentifier = videoInfo.identifier
            
            // Create a new player for the asset
            let player = AVPlayer(playerItem: AVPlayerItem(asset: videoInfo.asset))
            
            // Prepare player but keep it paused and muted
            player.isMuted = true
            player.pause()
            
            // Seek to the start position
            let startTime = CMTime(seconds: videoInfo.startPosition, preferredTimescale: 600)
            await player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
            
            // Store reference to next player
            nextPlayer = player
            
            // Mark next video as ready
            nextVideoReady = true
        } catch {
            // Retry on error after a short delay
            try? await Task.sleep(for: .seconds(0.5))
            await preloadNextVideo()
        }
    }
    
    private func completeTransition(geometry: GeometryProxy) {
        guard nextVideoReady, let nextPlayer = nextPlayer else { return }
        
        // Mark as transitioning to prevent gesture conflicts
        isTransitioning = true
        
        // Animate transition to completion
        withAnimation(.easeOut(duration: animationDuration)) {
            dragOffset = geometry.size.height
        }
        
        // After animation completes, swap next to current
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            // Stop old player
            viewModel.player?.pause()
            
            // Save the previous identifier to remove from cache
            let previousIdentifier = viewModel.currentIdentifier
            
            // Update the view model with the new video's metadata
            viewModel.currentTitle = nextTitle
            viewModel.currentCollection = nextCollection
            viewModel.currentDescription = nextDescription
            viewModel.currentIdentifier = nextIdentifier
            
            // Unmute the new player and play it
            nextPlayer.isMuted = false
            
            // Set the new player as current
            viewModel.player = nextPlayer
            
            // Play the new current video
            nextPlayer.play()
            
            // Reset animation state
            dragOffset = 0
            isDragging = false
            isTransitioning = false
            nextVideoReady = false
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
                await preloadNextVideo()
            }
        }
    }
}

#Preview {
    // Use a mock ViewModel for preview
    let viewModel = VideoPlayerViewModel()
    return SwipeableVideoView(viewModel: viewModel)
}