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
    
    var body: some View {
        ZStack {
            // Black background
            Color.black.ignoresSafeArea()
            
            if viewModel.isLoading {
                // Show loading screen during initialization
                LoadingView()
            } else if let error = viewModel.errorMessage {
                // Show error screen when there's an error
                ErrorView(error: error) {
                    Task {
                        await viewModel.loadRandomVideo()
                    }
                }
            } else {
                // Use the shared swipeable player component
                SwipeablePlayerView(provider: viewModel)
            }
        }
        .onAppear {
            // Ensure we have a video loaded if needed
            if viewModel.player == nil && !viewModel.isLoading {
                Task {
                    Logger.caching.info("SwipeableVideoView: No video loaded, loading first video")
                    await viewModel.loadRandomVideo()
                }
            }
        }
    }
}

#Preview {
    // Use a mock ViewModel for preview
    SwipeableVideoView(viewModel: VideoPlayerViewModel(favoritesManager: FavoritesManager()))
}