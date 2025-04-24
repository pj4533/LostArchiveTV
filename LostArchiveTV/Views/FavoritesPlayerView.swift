//
//  FavoritesPlayerView.swift
//  LostArchiveTV
//
//  Created by Claude on 4/24/25.
//

import SwiftUI
import AVKit

struct FavoritesPlayerView: View {
    @ObservedObject var viewModel: FavoritesViewModel
    @Binding var isPresented: Bool
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    private let dragThreshold: CGFloat = 100
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if let video = viewModel.currentVideo {
                    // Video player content
                    ZStack {
                        if let player = viewModel.player {
                            VideoPlayer(player: player)
                                .aspectRatio(16/9, contentMode: .fit)
                                .edgesIgnoringSafeArea(.all)
                        }
                        
                        // Controls
                        VStack {
                            // Top controls
                            HStack {
                                // Back button
                                Button(action: {
                                    isPresented = false
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
                                
                                // Favorite button
                                Button(action: {
                                    viewModel.toggleFavorite()
                                    hapticFeedback()
                                }) {
                                    Image(systemName: viewModel.isFavorite(video) ? "heart.fill" : "heart")
                                        .font(.title2)
                                        .foregroundColor(viewModel.isFavorite(video) ? .red : .white)
                                        .padding(12)
                                        .background(Circle().fill(Color.black.opacity(0.5)))
                                }
                                .padding(.top, 50)
                                .padding(.trailing, 16)
                            }
                            
                            Spacer()
                            
                            // Bottom info panel
                            BottomInfoPanel(
                                title: video.title,
                                collection: video.collection,
                                description: video.description,
                                identifier: video.identifier,
                                currentTime: viewModel.player?.currentTime().seconds,
                                duration: viewModel.videoDuration
                            )
                        }
                    }
                    .offset(y: dragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if !isDragging {
                                    isDragging = true
                                }
                                dragOffset = value.translation.height
                            }
                            .onEnded { value in
                                isDragging = false
                                if dragOffset > dragThreshold {
                                    // Swipe down - previous video
                                    withAnimation {
                                        dragOffset = geometry.size.height
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        viewModel.goToPreviousVideo()
                                        dragOffset = 0
                                    }
                                } else if dragOffset < -dragThreshold {
                                    // Swipe up - next video
                                    withAnimation {
                                        dragOffset = -geometry.size.height
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        viewModel.goToNextVideo()
                                        dragOffset = 0
                                    }
                                } else {
                                    // Return to center
                                    withAnimation {
                                        dragOffset = 0
                                    }
                                }
                            }
                    )
                } else {
                    // No video selected or all favorites removed
                    VStack(spacing: 24) {
                        Image(systemName: "heart.slash")
                            .font(.system(size: 64))
                            .foregroundColor(.gray)
                        
                        Text("No Favorites")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Button("Return to Favorites") {
                            isPresented = false
                        }
                        .padding()
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    private func hapticFeedback() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

struct VideoInfo {
    let identifier: String
    let title: String
    let description: String
    let year: String
    let runtime: String
    let collection: String?
    let url: URL?
    let thumbnailURL: URL?
}