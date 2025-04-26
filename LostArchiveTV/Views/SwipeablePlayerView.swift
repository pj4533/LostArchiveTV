//
//  SwipeablePlayerView.swift
//  LostArchiveTV
//
//  Created by Claude on 4/24/25.
//

import SwiftUI
import AVKit
import OSLog

struct SwipeablePlayerView<Provider: VideoProvider & ObservableObject>: View {
    @ObservedObject var provider: Provider
    @StateObject private var transitionManager = VideoTransitionManager()
    
    // Make the transitionManager accessible to the provider for direct preloading
    var onPreloadReady: ((VideoTransitionManager) -> Void)? = nil
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var showBackButton = false
    
    // Track the current step in the trim workflow
    @State private var trimStep: TrimWorkflowStep = .none
    @State private var downloadedVideoURL: URL? = nil
    
    // Optional binding for dismissal in modal presentations
    var isPresented: Binding<Bool>?
    
    // Enum for tracking trim workflow steps
    enum TrimWorkflowStep {
        case none        // No trim action in progress
        case downloading // Downloading video for trimming
        case trimming    // Showing trim interface
    }
    
    var body: some View {
        GeometryReader { geometry in
            // Use the VideoLayersView to manage the complex layering
            VideoLayersView(
                geometry: geometry,
                provider: provider,
                transitionManager: transitionManager,
                dragOffset: $dragOffset,
                isPresented: isPresented,
                showBackButton: showBackButton
            )
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            // Sheet for trim workflow (only when a trim step is active)
            .overlay {
                // Use a ZStack with conditional content for trim UI instead of a sheet
                if trimStep != .none {
                    ZStack {
                        // Semi-transparent black background
                        Color.black.opacity(0.9).ignoresSafeArea()
                        
                        // Use specific content view based on the current trim step
                        VStack {
                            if trimStep == .downloading {
                                // Download view
                                TrimDownloadView(provider: provider) { downloadedURL in
                                    if let url = downloadedURL {
                                        // Success - move to trim step
                                        self.downloadedVideoURL = url
                                        self.trimStep = .trimming
                                    } else {
                                        // Failed download - dismiss everything
                                        self.downloadedVideoURL = nil
                                        self.trimStep = .none
                                    }
                                }
                            } else if trimStep == .trimming, 
                                    let downloadedURL = downloadedVideoURL,
                                    let baseViewModel = provider as? BaseVideoViewModel {
                                // Get current time and duration from the player
                                let currentTimeSeconds = baseViewModel.player?.currentTime().seconds ?? 0
                                let durationSeconds = baseViewModel.videoDuration
                                
                                // Convert to CMTime for VideoTrimViewModel
                                let currentTime = CMTime(seconds: currentTimeSeconds, preferredTimescale: 600)
                                let duration = CMTime(seconds: durationSeconds, preferredTimescale: 600)
                                
                                // Trim view
                                VideoTrimView(viewModel: VideoTrimViewModel(
                                    assetURL: downloadedURL,
                                    currentPlaybackTime: currentTime,
                                    duration: duration
                                ))
                            }
                            Spacer()
                        }
                    }
                    .transition(.opacity)
                    .zIndex(100) // Ensure it's above all other content
                }
            }
            // Add gesture recognizer as a modifier
            .addVideoGestures(
                transitionManager: transitionManager,
                provider: provider,
                geometry: geometry,
                dragOffset: $dragOffset,
                isDragging: $isDragging
            )
            .onAppear {
                // Show back button if this is a modal presentation
                showBackButton = isPresented != nil
                
                // Notify the provider about the transition manager (for direct preloading)
                onPreloadReady?(transitionManager)
                
                // Ensure we have a video loaded and videos are ready for swiping in both directions
                if provider.player != nil {
                    Logger.caching.info("SwipeablePlayerView onAppear: Player exists, starting preload for \(String(describing: type(of: provider)))")
                    
                    if let favProvider = provider as? FavoritesViewModel {
                        Logger.caching.info("Favorites count: \(favProvider.favorites.count), currentIndex: \(favProvider.currentIndex)")
                        // Store transition manager in the favorites view model
                        favProvider.transitionManager = transitionManager
                    } else if let searchViewModel = provider as? SearchViewModel {
                        Logger.caching.info("Search results count: \(searchViewModel.searchResults.count), currentIndex: \(searchViewModel.currentIndex)")
                        // Store transition manager in the search view model
                        searchViewModel.transitionManager = transitionManager
                    }
                    
                    preloadVideos()
                } else {
                    Logger.caching.error("⚠️ SwipeablePlayerView onAppear: Player is nil, cannot preload")
                }
                
                // Setup notification observer for trim action
                setupTrimObserver()
            }
        }
    }
    
    // Helper function to preload videos for swiping
    private func preloadVideos() {
        Task {
            Logger.caching.info("SwipeablePlayerView: Preloading videos for bidirectional swiping")
            
            // Load both directions concurrently
            async let nextTask = transitionManager.preloadNextVideo(provider: provider)
            async let prevTask = transitionManager.preloadPreviousVideo(provider: provider)
            _ = await (nextTask, prevTask)
            
            // Log ready state after preloading
            Logger.caching.info("Preloading complete - nextVideoReady: \(transitionManager.nextVideoReady), prevVideoReady: \(transitionManager.prevVideoReady)")
        }
    }
    
    // Setup notification observer for trim action
    private func setupTrimObserver() {
        // Use NotificationCenter to communicate between components
        NotificationCenter.default.addObserver(
            forName: .startVideoTrimming,
            object: nil,
            queue: .main
        ) { _ in
            startTrimFlow()
        }
    }
    
    // Function to start the trim flow for any video provider
    private func startTrimFlow() {
        guard let _ = provider as? BaseVideoViewModel else { return }
        
        // Log the action
        Logger.caching.debug("Starting trim flow for \(type(of: provider))")
        
        // Start the trim workflow with the download step
        trimStep = .downloading
    }
}

#Preview {
    SwipeablePlayerView(provider: VideoPlayerViewModel(favoritesManager: FavoritesManager()))
}