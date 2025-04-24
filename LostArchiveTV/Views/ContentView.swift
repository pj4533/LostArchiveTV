//
//  ContentView.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import SwiftUI
import AVKit

struct ContentView: View {
    @StateObject private var favoritesManager = FavoritesManager()
    @StateObject private var videoPlayerViewModel: VideoPlayerViewModel
    
    init() {
        // Create the view model with the same favorites manager that will be used throughout the app
        let favManager = FavoritesManager()
        self._favoritesManager = StateObject(wrappedValue: favManager)
        self._videoPlayerViewModel = StateObject(wrappedValue: VideoPlayerViewModel(favoritesManager: favManager))
    }
    
    var body: some View {
        TabView {
            // Home Tab
            homeTab
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            // Favorites Tab
            FavoritesView(favoritesManager: favoritesManager)
                .tabItem {
                    Label("Favorites", systemImage: "heart.fill")
                }
        }
        .accentColor(.white)
        .preferredColorScheme(.dark)
    }
    
    private var homeTab: some View {
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