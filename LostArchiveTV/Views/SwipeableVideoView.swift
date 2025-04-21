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
                            identifier: transitionManager.nextIdentifier
                        )
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    // Position below current view, moves up as current view moves up
                    .offset(y: geometry.size.height - dragOffset)
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
                                await transitionManager.preloadNextVideo(
                                    viewModel: viewModel
                                )
                            }
                        }
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            // Gesture for vertical swipe - only enable when we have a video playing and next video is ready
            .gesture(
                viewModel.player == nil || viewModel.isLoading || !transitionManager.nextVideoReady ? nil :
                    DragGesture()
                    .onChanged { value in
                        guard !transitionManager.isTransitioning else { return }
                        
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
                        guard !transitionManager.isTransitioning && dragOffset > 0 else {
                            // If we're not actually dragging up, just reset
                            withAnimation(.spring(response: animationDuration, dampingFraction: 0.7)) {
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
                            transitionManager.completeTransition(
                                geometry: geometry,
                                viewModel: viewModel,
                                dragOffset: $dragOffset,
                                isDragging: $isDragging,
                                animationDuration: animationDuration
                            )
                        } else {
                            // Bounce back to original position
                            withAnimation(.spring(response: animationDuration, dampingFraction: 0.7)) {
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
                        if !transitionManager.nextVideoReady {
                            Logger.caching.info("SwipeableVideoView: Preloading next video for swiping")
                            await transitionManager.preloadNextVideo(
                                viewModel: viewModel
                            )
                        }
                    }
                } else if viewModel.player != nil && !transitionManager.nextVideoReady {
                    // Preload next video if we already have current video but no next video ready
                    Task {
                        Logger.caching.info("SwipeableVideoView: Current video loaded but next video not ready, preloading now")
                        await transitionManager.preloadNextVideo(
                            viewModel: viewModel
                        )
                    }
                } else {
                    Logger.caching.info("SwipeableVideoView: Video playing and next video ready")
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