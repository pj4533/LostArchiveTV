//
//  VideoLayersView.swift
//  LostArchiveTV
//
//  Created by Claude on 4/25/25.
//

import SwiftUI
import AVKit

struct VideoLayersView<Provider: VideoProvider & ObservableObject>: View {
    let geometry: GeometryProxy
    @ObservedObject var provider: Provider
    @ObservedObject var transitionManager: VideoTransitionManager
    @Binding var dragOffset: CGFloat
    
    // Optional binding for dismissal in modal presentations
    var isPresented: Binding<Bool>?
    var showBackButton: Bool
    
    var body: some View {
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
                                // Set isPresented to false first, then set player to nil after a short delay
                                isPresented.wrappedValue = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    favViewModel.player = nil
                                }
                            } else {
                                isPresented.wrappedValue = false
                            }
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
                        FavoritesVideoLayerContent(
                            player: player,
                            viewModel: favoritesViewModel,
                            isPresented: isPresented
                        )
                        .offset(y: dragOffset)
                    }
                }
            }
        }
    }
}

// Component for favorite video content layer
struct FavoritesVideoLayerContent: View {
    let player: AVPlayer
    @ObservedObject var viewModel: FavoritesViewModel
    var isPresented: Binding<Bool>?
    
    var body: some View {
        // Use the same layout as the main player
        ZStack {
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
                if let video = viewModel.currentVideo {
                    BottomInfoPanel(
                        title: video.title,
                        collection: video.collection,
                        description: video.description,
                        identifier: video.identifier,
                        currentTime: player.currentItem != nil ? player.currentTime().seconds : nil,
                        duration: viewModel.videoDuration
                    )
                }
                
                // Add custom back button for modal presentation
                if let isPresented = self.isPresented {
                    VStack {
                        HStack {
                            Button(action: {
                                // Stop playback before dismissing
                                viewModel.pausePlayback()
                                // Set isPresented to false first, then set player to nil after a short delay
                                isPresented.wrappedValue = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    viewModel.player = nil
                                }
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
                
                // Right-side button panel
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
                                viewModel.toggleFavorite()
                                // Add haptic feedback
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            },
                            disabled: viewModel.currentVideo == nil
                        ) {
                            Image(systemName: viewModel.currentVideo != nil && viewModel.isFavorite(viewModel.currentVideo!) ? "heart.fill" : "heart")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 22, height: 22)
                                .foregroundColor(viewModel.currentVideo != nil && viewModel.isFavorite(viewModel.currentVideo!) ? .red : .white)
                                .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                        }
                        
                        // Restart video button
                        OverlayButton(
                            action: {
                                viewModel.restartVideo()
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
                                viewModel.pausePlayback()
                                // Trigger trimming to be shown in the parent view
                                NotificationCenter.default.post(name: .startVideoTrimming, object: nil)
                            },
                            disabled: viewModel.currentVideo == nil
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
                            disabled: viewModel.currentVideo == nil
                        ) {
                            Image(systemName: "square.and.arrow.down.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 22, height: 22)
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                        }
                        
                        // Archive.org link button
                        if let identifier = viewModel.currentVideo?.identifier {
                            ArchiveButton(identifier: identifier)
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 50)
                }
            }
        }
    }
}

// Notification name for starting video trimming
extension Notification.Name {
    static let startVideoTrimming = Notification.Name("startVideoTrimming")
}