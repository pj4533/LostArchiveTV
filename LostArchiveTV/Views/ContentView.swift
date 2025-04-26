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
    @StateObject private var searchViewModel: SearchViewModel
    
    // Track the currently selected tab
    @State private var selectedTab = 0
    
    init() {
        // Create the view model with the same favorites manager that will be used throughout the app
        let favManager = FavoritesManager()
        self._favoritesManager = StateObject(wrappedValue: favManager)
        
        // Create video loading service to be shared
        let videoLoadingService = VideoLoadingService(
            archiveService: ArchiveService(),
            cacheManager: VideoCacheManager()
        )
        
        self._videoPlayerViewModel = StateObject(wrappedValue: VideoPlayerViewModel(
            favoritesManager: favManager
        ))
        
        self._favoritesViewModel = StateObject(wrappedValue: FavoritesViewModel(
            favoritesManager: favManager
        ))
        
        self._searchViewModel = StateObject(wrappedValue: SearchViewModel(
            videoLoadingService: videoLoadingService
        ))
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            homeTab
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            // Search Tab
            SearchView(viewModel: searchViewModel)
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(1)
            
            // Favorites Tab
            FavoritesView(favoritesManager: favoritesManager, viewModel: favoritesViewModel)
                .tabItem {
                    Label("Favorites", systemImage: "heart.fill")
                }
                .tag(2)
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
        
        switch (oldTab, newTab) {
        case (0, _):
            // Leaving home tab - pause main player if it's playing
            if videoPlayerViewModel.isPlaying {
                videoPlayerViewModel.pausePlayback()
            }
        case (1, _):
            // Leaving search tab - pause search player if it's playing
            if searchViewModel.isPlaying {
                searchViewModel.pausePlayback()
            }
        case (2, _):
            // Leaving favorites tab - pause favorites player if playing
            if favoritesViewModel.isPlaying {
                favoritesViewModel.pausePlayback()
            }
        default:
            break
        }
        
        // Resume the player on the tab we're switching to if needed
        if newTab == 0 && videoPlayerViewModel.player != nil {
            videoPlayerViewModel.resumePlayback()
        }
    }
}

#Preview {
    ContentView()
}