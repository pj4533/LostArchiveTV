//
//  SwipeablePlayerView.swift
//  LostArchiveTV
//
//  Created by Claude on 4/24/25.
//

import SwiftUI
import AVKit
import OSLog

// Helper class to manage notification observing - using a class allows us to properly handle deallocation
class TrimObserver: ObservableObject {
    private var token: NSObjectProtocol?
    @Published var trimStep: TrimWorkflowStep = .none
    
    enum TrimWorkflowStep {
        case none        // No trim action in progress
        case downloading // Downloading video for trimming
        case trimming    // Showing trim interface
    }
    
    func setupObserver(handler: @escaping () -> Void) {
        // Remove existing observer if it exists
        removeObserver()
        
        // Create a new observer
        token = NotificationCenter.default.addObserver(
            forName: .startVideoTrimming,
            object: nil,
            queue: .main
        ) { _ in
            handler()
        }
    }
    
    func removeObserver() {
        if let token = token {
            NotificationCenter.default.removeObserver(token)
            self.token = nil
        }
    }
    
    deinit {
        removeObserver()
    }
}

struct SwipeablePlayerView<Provider: VideoProvider & ObservableObject>: View {
    @ObservedObject var provider: Provider
    @StateObject private var transitionManager = VideoTransitionManager()
    @StateObject private var trimObserver = TrimObserver()
    
    // Make the transitionManager accessible to the provider for direct preloading
    var onPreloadReady: ((VideoTransitionManager) -> Void)? = nil
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var showBackButton = false
    
    // Track downloaded URL for trimming
    @State private var downloadedVideoURL: URL? = nil
    
    // Optional binding for dismissal in modal presentations
    var isPresented: Binding<Bool>?
    
    // Use the TrimWorkflowStep enum from TrimObserver
    typealias TrimWorkflowStep = TrimObserver.TrimWorkflowStep
    
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
                if trimObserver.trimStep != .none {
                    ZStack {
                        // Semi-transparent black background
                        Color.black.opacity(0.9).ignoresSafeArea()
                        
                        // Use specific content view based on the current trim step
                        VStack {
                            if trimObserver.trimStep == .downloading {
                                // Download view
                                TrimDownloadView(provider: provider) { downloadedURL in
                                    if let url = downloadedURL {
                                        // Success - move to trim step
                                        self.downloadedVideoURL = url
                                        self.trimObserver.trimStep = .trimming
                                    } else {
                                        // Failed download - dismiss everything
                                        self.downloadedVideoURL = nil
                                        self.trimObserver.trimStep = .none
                                    }
                                }
                            } else if trimObserver.trimStep == .trimming, 
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
                trimObserver.setupObserver {
                    startTrimFlow()
                }
            }
            .onDisappear {
                // Clean up resources when view disappears
                Logger.caching.debug("SwipeablePlayerView disappearing - removing observers")
                
                // Remove observer
                trimObserver.removeObserver()
                
                // Reset trim state
                trimObserver.trimStep = .none
                downloadedVideoURL = nil
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
    
    // Function to start the trim flow for any video provider
    private func startTrimFlow() {
        guard let _ = provider as? BaseVideoViewModel else { return }
        
        // Log the action
        Logger.caching.debug("Starting trim flow for \(type(of: provider))")
        
        // Start the trim workflow with the download step
        trimObserver.trimStep = .downloading
    }
}

#Preview {
    SwipeablePlayerView(provider: VideoPlayerViewModel(favoritesManager: FavoritesManager()))
}