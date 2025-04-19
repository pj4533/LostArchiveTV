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
            
            if videoPlayerViewModel.isLoading {
                LoadingView()
            } else if let player = videoPlayerViewModel.player {
                PlayerContentView(
                    player: player,
                    currentIdentifier: videoPlayerViewModel.currentIdentifier,
                    title: videoPlayerViewModel.currentTitle,
                    description: videoPlayerViewModel.currentDescription
                ) {
                    Task {
                        await videoPlayerViewModel.loadRandomVideo()
                    }
                }
            } else if let error = videoPlayerViewModel.errorMessage {
                ErrorView(error: error) {
                    Task {
                        await videoPlayerViewModel.loadRandomVideo()
                    }
                }
            }
        }
        .task {
            await videoPlayerViewModel.loadRandomVideo()
        }
    }
}

#Preview {
    ContentView()
}
