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
    
    // New feed view models
    @StateObject private var favoritesFeedViewModel: FavoritesFeedViewModel
    @StateObject private var searchFeedViewModel: SearchFeedViewModel
    
    // Track the currently selected tab
    @State private var selectedTab = 0
    
    init() {
        // Create the view model with the same favorites manager that will be used throughout the app
        let favManager = FavoritesManager()
        self._favoritesManager = StateObject(wrappedValue: favManager)
        
        // Create services to be shared
        let videoLoadingService = VideoLoadingService(
            archiveService: ArchiveService(),
            cacheManager: VideoCacheManager()
        )
        
        let searchManager = SearchManager()
        
        // Create view models
        let favViewModel = FavoritesViewModel(favoritesManager: favManager)
        self._favoritesViewModel = StateObject(wrappedValue: favViewModel)
        
        let searchVM = SearchViewModel(
            searchManager: searchManager,
            videoLoadingService: videoLoadingService,
            favoritesManager: favManager
        )
        self._searchViewModel = StateObject(wrappedValue: searchVM)
        
        self._videoPlayerViewModel = StateObject(wrappedValue: VideoPlayerViewModel(
            favoritesManager: favManager
        ))
        
        // Create feed view models
        self._favoritesFeedViewModel = StateObject(wrappedValue: FavoritesFeedViewModel(
            favoritesManager: favManager,
            favoritesViewModel: favViewModel
        ))
        
        self._searchFeedViewModel = StateObject(wrappedValue: SearchFeedViewModel(
            searchManager: searchManager,
            searchViewModel: searchVM
        ))
    }
    
    // State to track similar videos navigation
    @State var showingSimilarVideos = false
    @State var similarVideoIdentifier = ""

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                // Home Tab
                homeTab
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(0)
                
                // Search Tab
                SearchFeedView(viewModel: searchFeedViewModel)
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .tag(1)
                
                // Favorites Tab
                FavoritesFeedView(viewModel: favoritesFeedViewModel)
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
            .navigationDestination(isPresented: $showingSimilarVideos) {
                // Pass the shared SearchViewModel instead of creating a new one
                SimilarView(referenceIdentifier: similarVideoIdentifier, searchViewModel: searchViewModel)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSimilarVideos)) { notification in
            if let identifier = notification.userInfo?["identifier"] as? String {
                // Set the identifier and trigger navigation
                similarVideoIdentifier = identifier
                showingSimilarVideos = true
                
                // Close any open modal players if needed
                if searchFeedViewModel.showingPlayer {
                    searchFeedViewModel.showingPlayer = false
                    Task {
                        await searchFeedViewModel.searchViewModel.pausePlayback()
                    }
                }
                if favoritesFeedViewModel.showPlayer {
                    favoritesFeedViewModel.showPlayer = false
                    Task {
                        await favoritesFeedViewModel.favoritesViewModel.pausePlayback()
                    }
                }
            }
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
        
        // Using Task to handle async calls
        Task {
            switch (oldTab, newTab) {
            case (0, _):
                // Leaving home tab - pause main player if it's playing
                if videoPlayerViewModel.isPlaying {
                    await videoPlayerViewModel.pausePlayback()
                }
            case (1, _):
                // Leaving search tab - pause search player if it's playing
                if searchFeedViewModel.searchViewModel.isPlaying {
                    await searchFeedViewModel.searchViewModel.pausePlayback()
                }
            case (2, _):
                // Leaving favorites tab - pause favorites player if playing
                if favoritesFeedViewModel.favoritesViewModel.isPlaying {
                    await favoritesFeedViewModel.favoritesViewModel.pausePlayback()
                }
            default:
                break
            }
            
            // Resume the player on the tab we're switching to if needed
            if newTab == 0 && videoPlayerViewModel.player != nil {
                await videoPlayerViewModel.resumePlayback()
            }
        }
    }
}

#Preview {
    ContentView()
}