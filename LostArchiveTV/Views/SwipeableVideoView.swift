//
//  SwipeableVideoView.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import SwiftUI
import AVKit

struct SwipeableVideoView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var isTransitioning = false
    
    // Constants for animation
    private let swipeThreshold: CGFloat = 100
    private let animationDuration = 0.3
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Black background
                Color.black.ignoresSafeArea()
                
                // Content based on state
                if viewModel.isLoading {
                    // Show loading screen while loading a video
                    LoadingView()
                } else if let error = viewModel.errorMessage {
                    // Show error screen when there's an error
                    ErrorView(error: error) {
                        Task {
                            await viewModel.loadRandomVideo()
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
                            }
                        }
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            // Gesture for vertical swipe - only enable when we have a video playing
            .gesture(
                viewModel.player == nil || viewModel.isLoading ? nil :
                    DragGesture()
                    .onChanged { value in
                        guard !isTransitioning else { return }
                        
                        let translation = value.translation.height
                        isDragging = true
                        // Only allow upward swipes (negative translation values)
                        if translation < 0 {
                            // Convert negative translation to positive offset
                            dragOffset = -translation
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
                            playNextVideo(geometry: geometry)
                        } else {
                            // Bounce back to original position
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                dragOffset = 0
                                isDragging = false
                            }
                        }
                    }
            )
            .onChange(of: viewModel.isLoading) { _, newValue in
                // Reset dragging state when loading state changes
                if !newValue && isDragging {
                    withAnimation {
                        dragOffset = 0
                        isDragging = false
                        isTransitioning = false
                    }
                }
            }
            .onAppear {
                // Ensure we have a video loaded
                if viewModel.player == nil && !viewModel.isLoading {
                    Task {
                        await viewModel.loadRandomVideo()
                    }
                }
            }
        }
    }
    
    private func playNextVideo(geometry: GeometryProxy) {
        // Mark as transitioning to prevent gesture conflicts
        isTransitioning = true
        
        // Animate current video off-screen
        withAnimation(.easeOut(duration: animationDuration)) {
            dragOffset = geometry.size.height
        }
        
        // Start loading next video
        DispatchQueue.main.asyncAfter(deadline: .now() + (animationDuration * 0.5)) {
            Task {
                await viewModel.loadRandomVideo()
            }
        }
        
        // Reset after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            dragOffset = 0
            isDragging = false
            isTransitioning = false
        }
    }
}

#Preview {
    // Use a mock ViewModel for preview
    let viewModel = VideoPlayerViewModel()
    return SwipeableVideoView(viewModel: viewModel)
}