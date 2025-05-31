//
//  SwipeablePlayerView.swift
//  LostArchiveTV
//
//  Created by Claude on 4/24/25.
//

import SwiftUI
import AVKit
import AVFoundation
import OSLog

struct SwipeablePlayerView<Provider: VideoProvider & ObservableObject>: View {
    @ObservedObject var provider: Provider
    // Use the provider's transition manager instead of creating a new one
    private var transitionManager: VideoTransitionManager {
        // Return the provider's transition manager if it exists
        return provider.transitionManager ?? VideoTransitionManager()
    }
    @StateObject private var viewState = PlayerViewState()

    // Make the transitionManager accessible to the provider for direct preloading
    var onPreloadReady: ((VideoTransitionManager) -> Void)? = nil
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var showBackButton = false

    // Track downloaded URL for trimming
    @State private var downloadedVideoURL: URL? = nil

    // Optional binding for dismissal in modal presentations
    var isPresented: Binding<Bool>?

    // Use the TrimWorkflowStep enum from PlayerViewState
    typealias TrimWorkflowStep = PlayerViewState.TrimWorkflowStep
    
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
                ZStack {
                    // Trim overlay
                    TrimOverlayView(
                        provider: provider,
                        viewState: viewState,
                        downloadedVideoURL: $downloadedVideoURL
                    )

                    // Saved identifier notification overlay
                    NotificationOverlayView(viewState: viewState)
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
            // Present preset selection sheet when the provider's isShowingPresetSelection is true
            .sheet(isPresented: checkIfBaseViewModel() ?? .constant(false)) {
                if let baseViewModel = provider as? BaseVideoViewModel,
                   let data = baseViewModel.presetSelectionData {
                    PresetSelectionView(
                        viewModel: HomeFeedSettingsViewModel(databaseService: DatabaseService.shared),
                        isPresented: checkIfBaseViewModel() ?? .constant(false),
                        identifier: data.identifier,
                        title: data.title,
                        collection: data.collection,
                        fileCount: data.fileCount,
                        onSave: { title, presetName in
                            // Show saved confirmation
                            viewState.showSavedConfirmation(title: title, presetName: presetName)
                            
                            // Also close the sheet
                            baseViewModel.isShowingPresetSelection = false
                            baseViewModel.presetSelectionData = nil
                        }
                    )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
            }
            .onAppear {
                // Show back button if this is a modal presentation
                showBackButton = isPresented != nil
                
                // Assign transition manager to provider
                configureProvider(provider)
                
                // Ensure we have a video loaded and videos are ready for swiping in both directions
                if provider.player != nil {
                    Logger.caching.info("SwipeablePlayerView onAppear: Player exists, starting preload for \(String(describing: type(of: provider)))")
                    preloadVideos()
                } else {
                    Logger.caching.error("⚠️ SwipeablePlayerView onAppear: Player is nil, cannot preload")
                }
                
                // Setup trim observer
                viewState.setupTrimObserver {
                    startTrimFlow()
                }
                
                // Setup notification observer
                viewState.setupNotificationObserver()
            }
            .onDisappear {
                // Clean up resources when view disappears
                Logger.caching.debug("SwipeablePlayerView disappearing - removing observers")

                // Remove observers
                viewState.removeObservers()

                // Reset trim state
                viewState.trimStep = .none
                downloadedVideoURL = nil
            }
        }
    }
    
    // Configure any additional provider setup if needed
    private func configureProvider(_ provider: Provider) {
        // Log the transition manager we're using
        Logger.caching.info("Using provider's transition manager: \(String(describing: ObjectIdentifier(transitionManager)))")

        // Use the callback if provided (for custom provider types)
        onPreloadReady?(transitionManager)
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
        viewState.trimStep = .downloading
    }
    
    // Helper function to get BaseVideoViewModel binding for sheet presentation
    private func checkIfBaseViewModel() -> Binding<Bool>? {
        if let baseViewModel = provider as? BaseVideoViewModel {
            return Binding<Bool>(
                get: { baseViewModel.isShowingPresetSelection },
                set: { baseViewModel.isShowingPresetSelection = $0 }
            )
        }
        return nil
    }
}

#Preview {
    SwipeablePlayerView(provider: VideoPlayerViewModel(favoritesManager: FavoritesManager()))
}