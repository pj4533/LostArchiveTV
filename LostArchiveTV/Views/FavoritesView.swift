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
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
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
            .fullScreenCover(isPresented: $showPlayer) {
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
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(viewModel.favorites.enumerated()), id: \.element.id) { index, video in
                    VideoThumbnailView(video: video)
                        .aspectRatio(1, contentMode: .fill)
                        .frame(minHeight: 120)
                        .cornerRadius(8)
                        .onTapGesture {
                            // Start loading the video
                            viewModel.playVideoAt(index: index)
                            
                            // Show the player after a brief delay to ensure initialization completes
                            // This gives time for the player to be created and ready for display
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                showPlayer = true
                            }
                        }
                }
            }
            .padding()
        }
    }
}

struct VideoThumbnailView: View {
    let video: CachedVideo
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Thumbnail image
            thumbnailImage
            
            // Title overlay at bottom
            VStack(alignment: .leading, spacing: 2) {
                Text(video.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundColor(.white)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.black.opacity(0.8), .clear]),
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
        }
        .background(Color.gray.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var thumbnailImage: some View {
        Group {
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
                        ZStack {
                            Color.gray.opacity(0.3)
                            Image(systemName: "film")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                        }
                    @unknown default:
                        Color.gray.opacity(0.3)
                    }
                }
            } else {
                ZStack {
                    Color.gray.opacity(0.3)
                    Image(systemName: "film")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                }
            }
        }
    }
}