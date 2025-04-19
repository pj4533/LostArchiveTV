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
                // Current video
                if let player = viewModel.player {
                    VideoPlayerContent(
                        player: player,
                        viewModel: viewModel,
                        offset: min(dragOffset, 0),
                        opacity: 1.0 - min(abs(dragOffset) / geometry.size.height, 0.5)
                    )
                    
                    // Interface elements that move with the swipe
                    VideoInfoOverlay(
                        title: viewModel.currentTitle,
                        description: viewModel.currentDescription,
                        identifier: viewModel.currentIdentifier,
                        onNextTapped: {
                            playNextVideo()
                        }
                    )
                    .offset(y: min(dragOffset, 0))
                    .opacity(1.0 - min(abs(dragOffset) / (geometry.size.height / 2), 1.0))
                } else if viewModel.isLoading {
                    LoadingView()
                } else if let error = viewModel.errorMessage {
                    ErrorView(error: error) {
                        Task {
                            await viewModel.loadRandomVideo()
                        }
                    }
                }
                
                // Loading next video indicator (when swiping up)
                if dragOffset > 0 {
                    ProgressView("Loading next video...")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                        .opacity(min(dragOffset / (geometry.size.height / 2), 1.0))
                        .zIndex(1)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            // Gesture for vertical swipe
            .gesture(
                DragGesture()
                    .onChanged { value in
                        guard !isTransitioning else { return }
                        
                        let translation = value.translation.height
                        isDragging = true
                        dragOffset = -translation
                    }
                    .onEnded { value in
                        guard !isTransitioning else { return }
                        
                        let translation = value.translation.height
                        let velocity = value.predictedEndTranslation.height - value.translation.height
                        
                        // Determine if swipe should complete based on threshold or velocity
                        let shouldComplete = -translation > swipeThreshold || -velocity > 500
                        
                        if shouldComplete && -translation > 0 {
                            // Complete the swipe animation upward
                            withAnimation(.easeOut(duration: animationDuration)) {
                                dragOffset = geometry.size.height
                                isTransitioning = true
                            }
                            
                            // Load next video
                            DispatchQueue.main.asyncAfter(deadline: .now() + (animationDuration * 0.7)) {
                                playNextVideo()
                            }
                            
                            // Reset after animation completes
                            DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
                                dragOffset = 0
                                isDragging = false
                                isTransitioning = false
                            }
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
        .background(Color.black)
        .edgesIgnoringSafeArea(.all)
    }
    
    private func playNextVideo() {
        Task {
            await viewModel.loadRandomVideo()
        }
    }
}

// MARK: - Video Player Content
struct VideoPlayerContent: View {
    let player: AVPlayer
    let viewModel: VideoPlayerViewModel
    let offset: CGFloat
    let opacity: Double
    
    var body: some View {
        ZStack {
            Color.black
            
            VideoPlayer(player: player)
                .disabled(true) // Disable VideoPlayer's own gestures
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(y: offset)
                .opacity(opacity)
        }
    }
}

// MARK: - Video Info Overlay
struct VideoInfoOverlay: View {
    let title: String?
    let description: String?
    let identifier: String?
    let onNextTapped: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            
            // Bottom overlay with title and description
            VStack(alignment: .leading, spacing: 10) {
                // Next button
                Button(action: onNextTapped) {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                        Text("Next Video")
                    }
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(25)
                }
                .padding(.bottom, 10)
                
                // Video title and description
                VStack(alignment: .leading, spacing: 5) {
                    Text(title ?? identifier ?? "Unknown Title")
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(description ?? "Internet Archive random video clip")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 25)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        
        // Swipe hint
        VStack {
            Spacer()
            
            Text("Swipe up for next video")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .padding(.bottom, 160) // Position above the controls
            
            Spacer().frame(height: 50)
        }
    }
}

#Preview {
    // Use a mock ViewModel for preview
    let viewModel = VideoPlayerViewModel()
    return SwipeableVideoView(viewModel: viewModel)
}