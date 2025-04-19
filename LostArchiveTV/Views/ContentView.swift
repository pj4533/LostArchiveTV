//
//  ContentView.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import SwiftUI
import AVKit

struct ContentView: View {
    @StateObject private var videoPlayerViewModel = VideoPlayerViewModel()
    
    var body: some View {
        ZStack {
            // Black background
            Color.black.ignoresSafeArea()
            
            // Main content
            if videoPlayerViewModel.isInitializing {
                // Show the simplified loading screen during initialization
                LoadingView()
            } else {
                // Use the swipeable video container once initialization is complete
                SwipeableVideoView(viewModel: videoPlayerViewModel)
            }
        }
    }
}

#Preview {
    ContentView()
}