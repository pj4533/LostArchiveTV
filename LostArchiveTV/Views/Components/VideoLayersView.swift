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