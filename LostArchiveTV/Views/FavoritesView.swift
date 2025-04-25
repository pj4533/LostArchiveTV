//
//  FavoritesView.swift
//  LostArchiveTV
//
//  Created by Claude on 4/24/25.
//

import SwiftUI
import AVKit

struct FavoritesView: View {
    @ObservedObject var viewModel: FavoritesViewModel
    @State private var showPlayer = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1)
    ]
    
    init(favoritesManager: FavoritesManager, viewModel: FavoritesViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if viewModel.favorites.isEmpty {
                    emptyStateView
                } else {
                    gridView
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.large)
            .fullScreenCover(isPresented: $showPlayer, onDismiss: {
                // Stop playback when the player is dismissed
                viewModel.pausePlayback()
                viewModel.player = nil
            }) {
                SwipeablePlayerView(provider: viewModel, isPresented: $showPlayer)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "heart.slash")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("No Favorites Yet")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Add videos to your favorites from the Home tab by tapping the heart icon")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(Array(viewModel.favorites.enumerated()), id: \.element.id) { index, video in
                    FavoriteCell(video: video, index: index, viewModel: viewModel, showPlayer: $showPlayer)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 1)
        }
    }
}

struct FavoriteCell: View {
    let video: CachedVideo
    let index: Int
    let viewModel: FavoritesViewModel
    @Binding var showPlayer: Bool
    
    var body: some View {
        VideoThumbnailView(video: video)
            .aspectRatio(1, contentMode: .fill)
            .frame(minWidth: 0, maxWidth: .infinity)
            .clipped()
            .onTapGesture {
                // Start loading the video
                viewModel.playVideoAt(index: index)
                
                // Show the player after a brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showPlayer = true
                }
            }
    }
}

struct VideoThumbnailView: View {
    let video: CachedVideo
    
    var body: some View {
        ZStack {
            if let thumbnailURL = video.thumbnailURL {
                AsyncImage(url: thumbnailURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        fallbackImage
                    @unknown default:
                        fallbackImage
                    }
                }
            } else {
                fallbackImage
            }
        }
        .background(Color.gray.opacity(0.3))
    }
    
    private var fallbackImage: some View {
        ZStack {
            Color.gray.opacity(0.3)
            Image(systemName: "film")
                .font(.largeTitle)
                .foregroundColor(.white)
        }
    }
}