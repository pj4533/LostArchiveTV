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
    @StateObject private var transitionManager = VideoTransitionManager()
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    // Constants for animation
    private let swipeThreshold: CGFloat = 100
    private let animationDuration = 0.15
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Black background
                Color.black.ignoresSafeArea()
                
                // Previous video positioned above current video
                if let prevPlayer = transitionManager.prevPlayer, transitionManager.prevVideoReady {
                    ZStack {
                        // Previous video content
                        VideoPlayerContent(
                            player: prevPlayer,
                            viewModel: viewModel
                        )
                        
                        // Previous video info
                        VideoInfoOverlay(
                            title: transitionManager.prevTitle,
                            collection: transitionManager.prevCollection,
                            description: transitionManager.prevDescription,
                            identifier: transitionManager.prevIdentifier,
                            viewModel: viewModel
                        )
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    // Position above current view, moves down as current view moves down
                    .offset(y: -geometry.size.height + dragOffset)
                }
                
                // Next video positioned below current video
                if let nextPlayer = transitionManager.nextPlayer, transitionManager.nextVideoReady {
                    ZStack {
                        // Next video content
                        VideoPlayerContent(
                            player: nextPlayer,
                            viewModel: viewModel
                        )
                        
                        // Next video info
                        VideoInfoOverlay(
                            title: transitionManager.nextTitle,
                            collection: transitionManager.nextCollection,
                            description: transitionManager.nextDescription,
                            identifier: transitionManager.nextIdentifier,
                            viewModel: viewModel
                        )
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    // Position below current view, moves up as current view moves up
                    .offset(y: geometry.size.height + dragOffset)
                }
                
                // Current video
                if viewModel.isLoading && transitionManager.nextPlayer == nil {
                    // Show loading screen only for initial load
                    LoadingView()
                } else if let error = viewModel.errorMessage {
                    // Show error screen when there's an error
                    ErrorView(error: error) {
                        Task {
                            await transitionManager.preloadNextVideo(
                                viewModel: viewModel
                            )
                        }
                    }
                } else if let player = viewModel.player {
                    // Show the current video when available
                    ZStack {
                        // Current video content - moves with swipe
                        VideoPlayerContent(
                            player: player,
                            viewModel: viewModel
                        )
                        .offset(y: dragOffset)  // Move based on drag - IMPORTANT: positive for down, negative for up
                        
                        // Bottom video info - moves with video
                        VideoInfoOverlay(
                            title: viewModel.currentTitle,
                            collection: viewModel.currentCollection,
                            description: viewModel.currentDescription,
                            identifier: viewModel.currentIdentifier,
                            viewModel: viewModel
                        )
                        .offset(y: dragOffset)
                    }
                } else {
                    // Fallback if player isn't loaded yet but not in loading state
                    LoadingView()
                    
                    // Auto-trigger video load if needed
                    .onAppear {
                        if !viewModel.isLoading {
                            Task {
                                await viewModel.loadRandomVideo()
                                
                                // Load both directions in parallel
                                async let nextTask = transitionManager.preloadNextVideo(viewModel: viewModel)
                                async let prevTask = transitionManager.preloadPreviousVideo(viewModel: viewModel)
                                _ = await (nextTask, prevTask)
                            }
                        }
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            // Gesture for vertical swipe - only enable when we have a video playing
            .simultaneousGesture(
                viewModel.player == nil || viewModel.isLoading ? nil :
                    DragGesture()
                    .onChanged { value in
                        guard !transitionManager.isTransitioning else { return }
                        
                        let translation = value.translation.height
                        isDragging = true
                        
                        // Allow both upward and downward swipes
                        if translation < 0 {
                            // Upward swipe (for next video) - only if next video is ready
                            if transitionManager.nextVideoReady {
                                dragOffset = max(translation, -geometry.size.height)
                            }
                        } else {
                            // Downward swipe (for previous video) - only if previous video is ready
                            if transitionManager.prevVideoReady {
                                dragOffset = min(translation, geometry.size.height)
                            }
                        }
                    }
                    .onEnded { value in
                        guard !transitionManager.isTransitioning else { return }
                        
                        let translation = value.translation.height
                        let velocity = value.predictedEndTranslation.height - value.translation.height
                        
                        // If we're not actually dragging significantly, just reset
                        if abs(dragOffset) < 10 {
                            withAnimation(.spring(response: animationDuration, dampingFraction: 0.7)) {
                                dragOffset = 0
                                isDragging = false
                            }
                            return
                        }
                        
                        if dragOffset < 0 {
                            // Upward swipe (next video)
                            let shouldComplete = -dragOffset > swipeThreshold || -velocity > 500
                            
                            if shouldComplete && transitionManager.nextVideoReady {
                                // Complete the swipe animation upward (to next video)
                                transitionManager.completeTransition(
                                    geometry: geometry,
                                    viewModel: viewModel,
                                    dragOffset: $dragOffset,
                                    isDragging: $isDragging,
                                    animationDuration: animationDuration,
                                    direction: .up
                                )
                            } else {
                                // Bounce back to original position
                                withAnimation(.spring(response: animationDuration, dampingFraction: 0.7)) {
                                    dragOffset = 0
                                    isDragging = false
                                }
                            }
                        } else if dragOffset > 0 {
                            // Downward swipe (previous video)
                            let shouldComplete = dragOffset > swipeThreshold || velocity > 500
                            
                            if shouldComplete && transitionManager.prevVideoReady {
                                // Complete the swipe animation downward (to previous video)
                                transitionManager.completeTransition(
                                    geometry: geometry,
                                    viewModel: viewModel,
                                    dragOffset: $dragOffset,
                                    isDragging: $isDragging,
                                    animationDuration: animationDuration,
                                    direction: .down
                                )
                            } else {
                                // Bounce back to original position
                                withAnimation(.spring(response: animationDuration, dampingFraction: 0.7)) {
                                    dragOffset = 0
                                    isDragging = false
                                }
                            }
                        } else {
                            // Reset animation if no significant drag
                            withAnimation(.spring(response: animationDuration, dampingFraction: 0.7)) {
                                dragOffset = 0
                                isDragging = false
                            }
                        }
                    }
            )
            .onAppear {
                // Ensure we have a video loaded and videos are ready for swiping in both directions
                if viewModel.player == nil && !viewModel.isLoading {
                    Task {
                        Logger.caching.info("SwipeableVideoView: No video loaded, loading first video")
                        await viewModel.loadRandomVideo()
                        
                        // Preload videos in both directions for swiping
                        Logger.caching.info("SwipeableVideoView: Preloading videos for bidirectional swiping")
                        
                        // Load both directions concurrently
                        async let nextTask = transitionManager.preloadNextVideo(viewModel: viewModel)
                        async let prevTask = transitionManager.preloadPreviousVideo(viewModel: viewModel)
                        _ = await (nextTask, prevTask)
                    }
                } else if viewModel.player != nil {
                    // Preload videos if needed in either direction
                    Task {
                        // Preload next video if not ready
                        if !transitionManager.nextVideoReady {
                            Logger.caching.info("SwipeableVideoView: Preloading next video for swiping")
                            await transitionManager.preloadNextVideo(viewModel: viewModel)
                        }
                        
                        // Preload previous video if not ready
                        if !transitionManager.prevVideoReady {
                            Logger.caching.info("SwipeableVideoView: Preloading previous video for swiping")
                            await transitionManager.preloadPreviousVideo(viewModel: viewModel)
                        }
                    }
                } else {
                    Logger.caching.info("SwipeableVideoView: Video player initialized")
                }
            }
        }
    }
}

#Preview {
    // Use a mock ViewModel for preview
    let viewModel = VideoPlayerViewModel()
    return SwipeableVideoView(viewModel: viewModel)
}