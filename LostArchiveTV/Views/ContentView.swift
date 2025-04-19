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
            Color.black.ignoresSafeArea()
            
            // Use the new swipeable video container
            SwipeableVideoView(viewModel: videoPlayerViewModel)
        }
        .task {
            // Initial video load when the app launches
            await videoPlayerViewModel.loadRandomVideo()
        }
    }
}

#Preview {
    ContentView()
}