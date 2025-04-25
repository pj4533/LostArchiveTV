//
//  SwipeablePlayerView.swift
//  LostArchiveTV
//
//  Created by Claude on 4/24/25.
//

import SwiftUI
import AVKit
import OSLog

struct SwipeablePlayerView<Provider: VideoProvider & ObservableObject>: View {
    @ObservedObject var provider: Provider
    @StateObject private var transitionManager = VideoTransitionManager()
    
    // Make the transitionManager accessible to the provider for direct preloading
    var onPreloadReady: ((VideoTransitionManager) -> Void)? = nil
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var showBackButton = false
    
    // Optional binding for dismissal in modal presentations
    var isPresented: Binding<Bool>?
    
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
                        if let videoPlayerViewModel = provider as? VideoPlayerViewModel {
                            VideoPlayerContent(
                                player: prevPlayer,
                                viewModel: videoPlayerViewModel
                            )
                        } else {
                            VideoPlayer(player: prevPlayer)
                        }
                        
                        // Previous video info
                        if let videoPlayerViewModel = provider as? VideoPlayerViewModel {
                            VideoInfoOverlay(
                                title: transitionManager.prevTitle,
                                collection: transitionManager.prevCollection,
                                description: transitionManager.prevDescription,
                                identifier: transitionManager.prevIdentifier,
                                viewModel: videoPlayerViewModel
                            )
                        } else {
                            // Text view for previous video removed
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    // Position above current view, moves down as current view moves down
                    .offset(y: -geometry.size.height + dragOffset)
                }
                
                // Next video positioned below current video
                if let nextPlayer = transitionManager.nextPlayer, transitionManager.nextVideoReady {
                    ZStack {
                        // Next video content
                        if let videoPlayerViewModel = provider as? VideoPlayerViewModel {
                            VideoPlayerContent(
                                player: nextPlayer,
                                viewModel: videoPlayerViewModel
                            )
                        } else {
                            VideoPlayer(player: nextPlayer)
                        }
                        
                        // Next video info
                        if let videoPlayerViewModel = provider as? VideoPlayerViewModel {
                            VideoInfoOverlay(
                                title: transitionManager.nextTitle,
                                collection: transitionManager.nextCollection,
                                description: transitionManager.nextDescription,
                                identifier: transitionManager.nextIdentifier,
                                viewModel: videoPlayerViewModel
                            )
                        } else {
                            // Text view for next video removed
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    // Position below current view, moves up as current view moves up
                    .offset(y: geometry.size.height + dragOffset)
                }
                
                // Back button for modal presentation
                if showBackButton, let isPresented = isPresented {
                    VStack {
                        HStack {
                            Button(action: {
                                // Stop playback before dismissing
                                if let favViewModel = provider as? FavoritesViewModel {
                                    favViewModel.pausePlayback()
                                    favViewModel.player = nil
                                }
                                isPresented.wrappedValue = false
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                            }
                            .padding(.top, 50)
                            .padding(.leading, 16)
                            .zIndex(100)
                            
                            Spacer()
                        }
                        Spacer()
                    }
                }
                
                // Current video
                if let player = provider.player {
                    // Show the current video when available
                    ZStack {
                        // Current video content - moves with swipe
                        if let videoPlayerViewModel = provider as? VideoPlayerViewModel {
                            // For main player
                            VideoPlayerContent(
                                player: player,
                                viewModel: videoPlayerViewModel
                            )
                            .offset(y: dragOffset)  // Move based on drag
                            
                            // Bottom video info - moves with video
                            VideoInfoOverlay(
                                title: provider.currentTitle,
                                collection: provider.currentCollection,
                                description: provider.currentDescription,
                                identifier: provider.currentIdentifier,
                                viewModel: videoPlayerViewModel
                            )
                            .offset(y: dragOffset)
                        } else if let favoritesViewModel = provider as? FavoritesViewModel {
                            // For favorites player - use same components as main player for consistency
                            ZStack {
                                // Use the same layout as the main player
                                VStack(spacing: 0) {
                                    // Add spacing at top to start below the gear icon
                                    Spacer().frame(height: 70)
                                    
                                    // Actual player using maximum available width
                                    VideoPlayer(player: player)
                                        .aspectRatio(contentMode: .fit)
                                    
                                    // Reserve space for the timeline controls to appear here
                                    Spacer()
                                        .frame(height: 110)
                                        .frame(maxWidth: .infinity)
                                        .contentShape(Rectangle())
                                    
                                    // Additional spacer to ensure separation from video info overlay
                                    Spacer().frame(height: 100)
                                }
                                
                                // Create a VideoInfoOverlay-like stack with FavoritesButtonPanel
                                ZStack {
                                    // Bottom info panel
                                    if let video = favoritesViewModel.currentVideo {
                                        BottomInfoPanel(
                                            title: video.title,
                                            collection: video.collection,
                                            description: video.description,
                                            identifier: video.identifier,
                                            currentTime: player.currentTime().seconds,
                                            duration: favoritesViewModel.videoDuration
                                        )
                                    }
                                    
                                    // Add custom back button for modal presentation
                                    if let isPresented = self.isPresented {
                                        VStack {
                                            HStack {
                                                Button(action: {
                                                    // Stop playback before dismissing
                                                    if let favViewModel = provider as? FavoritesViewModel {
                                                        favViewModel.pausePlayback()
                                                        favViewModel.player = nil
                                                    }
                                                    isPresented.wrappedValue = false
                                                }) {
                                                    Image(systemName: "chevron.left")
                                                        .font(.title2)
                                                        .foregroundColor(.white)
                                                        .padding(12)
                                                        .background(Circle().fill(Color.black.opacity(0.5)))
                                                }
                                                .padding(.top, 50)
                                                .padding(.leading, 16)
                                                
                                                Spacer()
                                            }
                                            Spacer()
                                        }
                                    }
                                    
                                    // Right-side button panel (similar to main player)
                                    HStack {
                                        Spacer()
                                        
                                        VStack(spacing: 12) {
                                            // Settings-like placeholder at the top (back button replaces settings)
                                            // This preserves the vertical spacing to match the main player
                                            Color.clear
                                                .frame(width: 22, height: 22)
                                            
                                            Spacer()
                                            
                                            // Favorite button - same position as in main player (after spacer)
                                            OverlayButton(
                                                action: {
                                                    favoritesViewModel.toggleFavorite()
                                                    // Add haptic feedback
                                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                },
                                                disabled: favoritesViewModel.currentVideo == nil
                                            ) {
                                                Image(systemName: favoritesViewModel.currentVideo != nil && favoritesViewModel.isFavorite(favoritesViewModel.currentVideo!) ? "heart.fill" : "heart")
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(width: 22, height: 22)
                                                    .foregroundColor(favoritesViewModel.currentVideo != nil && favoritesViewModel.isFavorite(favoritesViewModel.currentVideo!) ? .red : .white)
                                                    .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                                            }
                                            
                                            // Restart video button
                                            OverlayButton(
                                                action: {
                                                    favoritesViewModel.restartVideo()
                                                },
                                                disabled: false
                                            ) {
                                                Image(systemName: "backward.end")
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(width: 16, height: 16)
                                                    .foregroundColor(.white)
                                                    .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                                            }
                                            
                                            // Trim button (enabled)
                                            OverlayButton(
                                                action: {
                                                    // Pause playback
                                                    favoritesViewModel.pausePlayback()
                                                    // TODO: Implement trim flow for favorites
                                                },
                                                disabled: favoritesViewModel.currentVideo == nil
                                            ) {
                                                Image(systemName: "selection.pin.in.out")
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(width: 22, height: 22)
                                                    .foregroundColor(.white)
                                                    .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                                            }
                                            
                                            // Download button
                                            OverlayButton(
                                                action: {
                                                    // TODO: Implement download for favorites
                                                },
                                                disabled: favoritesViewModel.currentVideo == nil
                                            ) {
                                                Image(systemName: "square.and.arrow.down.fill")
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(width: 22, height: 22)
                                                    .foregroundColor(.white)
                                                    .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                                            }
                                            
                                            // Archive.org link button
                                            if let identifier = favoritesViewModel.currentVideo?.identifier {
                                                ArchiveButton(identifier: identifier)
                                            }
                                        }
                                        .padding(.trailing, 16)
                                        .padding(.top, 50)
                                    }
                                }
                            }
                            .offset(y: dragOffset)
                        }
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            // Gesture for vertical swipe - only enable when we have a video playing
            .simultaneousGesture(
                provider.player == nil ? nil :
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
                                Logger.caching.debug("Dragging UP (next): nextVideoReady=true, dragOffset=\(dragOffset)")
                            } else {
                                Logger.caching.debug("⚠️ BLOCKED Dragging UP: nextVideoReady=false")
                            }
                        } else {
                            // Downward swipe (for previous video) - only if previous video is ready
                            if transitionManager.prevVideoReady {
                                dragOffset = min(translation, geometry.size.height)
                                Logger.caching.debug("Dragging DOWN (prev): prevVideoReady=true, dragOffset=\(dragOffset)")
                            } else {
                                Logger.caching.debug("⚠️ BLOCKED Dragging DOWN: prevVideoReady=false")
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
                                    provider: provider,
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
                                    provider: provider,
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
                // Show back button if this is a modal presentation
                showBackButton = isPresented != nil
                
                // Notify the provider about the transition manager (for direct preloading)
                onPreloadReady?(transitionManager)
                
                // Ensure we have a video loaded and videos are ready for swiping in both directions
                if provider.player != nil {
                    Logger.caching.info("SwipeablePlayerView onAppear: Player exists, starting preload for \(String(describing: type(of: provider)))")
                    
                    if let favProvider = provider as? FavoritesViewModel {
                        Logger.caching.info("Favorites count: \(favProvider.favorites.count), currentIndex: \(favProvider.currentIndex)")
                        // Store transition manager in the favorites view model
                        favProvider.transitionManager = transitionManager
                    }
                    
                    Task {
                        Logger.caching.info("SwipeablePlayerView: Preloading videos for bidirectional swiping")
                        
                        // Load both directions concurrently
                        async let nextTask = transitionManager.preloadNextVideo(provider: provider)
                        async let prevTask = transitionManager.preloadPreviousVideo(provider: provider)
                        _ = await (nextTask, prevTask)
                        
                        // Log ready state after preloading
                        Logger.caching.info("Preloading complete - nextVideoReady: \(transitionManager.nextVideoReady), prevVideoReady: \(transitionManager.prevVideoReady)")
                    }
                } else {
                    Logger.caching.error("⚠️ SwipeablePlayerView onAppear: Player is nil, cannot preload")
                }
            }
        }
    }
}

#Preview {
    SwipeablePlayerView(provider: VideoPlayerViewModel(favoritesManager: FavoritesManager()))
}