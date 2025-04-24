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
    @StateObject private var favoritesViewModel: FavoritesViewModel
    
    // Track the currently selected tab
    @State private var selectedTab = 0
    
    init() {
        // Create the view model with the same favorites manager that will be used throughout the app
        let favManager = FavoritesManager()
        self._favoritesManager = StateObject(wrappedValue: favManager)
        self._videoPlayerViewModel = StateObject(wrappedValue: VideoPlayerViewModel(favoritesManager: favManager))
        self._favoritesViewModel = StateObject(wrappedValue: FavoritesViewModel(favoritesManager: favManager))
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            homeTab
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            // Favorites Tab
            FavoritesView(favoritesManager: favoritesManager, viewModel: favoritesViewModel)
                .tabItem {
                    Label("Favorites", systemImage: "heart.fill")
                }
                .tag(1)
        }
        .accentColor(.white)
        .preferredColorScheme(.dark)
        .onChange(of: selectedTab) { oldValue, newValue in
            handleTabChange(oldTab: oldValue, newTab: newValue)
        }
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
    
    /// Handle switching between tabs by pausing the appropriate player
    private func handleTabChange(oldTab: Int, newTab: Int) {
        // Don't do anything if we're staying on the same tab
        guard oldTab != newTab else { return }
        
        if newTab == 0 {
            // Switched to Home tab - pause favorites player if playing
            if favoritesViewModel.isPlaying {
                favoritesViewModel.pausePlayback()
            }
            
            // Resume main player if it exists
            if videoPlayerViewModel.player != nil {
                videoPlayerViewModel.resumePlayback()
            }
        } else if newTab == 1 {
            // Switched to Favorites tab - pause main player if it's playing
            if videoPlayerViewModel.isPlaying {
                videoPlayerViewModel.pausePlayback()
            }
            
            // No need to resume favorites player automatically - it will play when a favorite is selected
        }
    }
}

#Preview {
    ContentView()
}