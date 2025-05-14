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

// Helper class to manage state for the SwipeablePlayerView
class PlayerViewState: ObservableObject {
    @Published var trimStep: TrimWorkflowStep = .none
    @Published var showSavedNotification = false
    @Published var savedIdentifierTitle = ""
    @Published var savedPresetName: String? = nil
    
    private var trimToken: NSObjectProtocol?

    enum TrimWorkflowStep {
        case none        // No trim action in progress
        case downloading // Downloading video for trimming
        case trimming    // Showing trim interface
    }

    func setupTrimObserver(handler: @escaping () -> Void) {
        // Remove existing observer if it exists
        removeObservers()

        // Create a new observer
        trimToken = NotificationCenter.default.addObserver(
            forName: .startVideoTrimming,
            object: nil,
            queue: .main
        ) { _ in
            handler()
        }
    }
    
    func showSavedConfirmation(title: String, presetName: String? = nil) {
        self.savedIdentifierTitle = title
        self.savedPresetName = presetName
        
        withAnimation {
            self.showSavedNotification = true
        }
    }

    func removeObservers() {
        if let token = trimToken {
            NotificationCenter.default.removeObserver(token)
            self.trimToken = nil
        }
    }

    deinit {
        removeObservers()
    }
}

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
                    // Use a ZStack with conditional content for trim UI instead of a sheet
                    if viewState.trimStep != .none {
                        ZStack {
                            // Semi-transparent black background
                            Color.black.opacity(0.9).ignoresSafeArea()

                            // Use specific content view based on the current trim step
                            VStack {
                                if viewState.trimStep == .downloading {
                                    // Download view
                                    TrimDownloadView(provider: provider) { downloadedURL in
                                        if let url = downloadedURL {
                                            // Success - move to trim step
                                            self.downloadedVideoURL = url
                                            self.viewState.trimStep = .trimming
                                        } else {
                                            // Failed download - dismiss everything
                                            self.downloadedVideoURL = nil
                                            self.viewState.trimStep = .none
                                        }
                                    }
                                } else if viewState.trimStep == .trimming,
                                        let downloadedURL = downloadedVideoURL,
                                        let baseViewModel = provider as? BaseVideoViewModel {
                                    // Get current time and duration from the player
                                    let currentTimeSeconds = baseViewModel.player?.currentTime().seconds ?? 0
                                    let durationSeconds = baseViewModel.videoDuration

                                    // Convert to CMTime for VideoTrimView
                                    let currentTime = CMTime(seconds: currentTimeSeconds, preferredTimescale: 600)
                                    let duration = CMTime(seconds: durationSeconds, preferredTimescale: 600)

                                    // Show the visual timeline-based trim view
                                    VideoTrimView(
                                        videoURL: downloadedURL,
                                        currentTime: currentTime,
                                        duration: duration,
                                        playbackManager: (baseViewModel as? VideoPlayerViewModel)?.playbackManager ?? VideoPlaybackManager()
                                    )
                                    .onAppear {
                                        // IMPORTANT: Give the trim view a longer delay to initialize
                                        Task {
                                            // First explicitly pause the current player to avoid conflicts
                                            if let baseViewModel = provider as? BaseVideoViewModel, let player = baseViewModel.player {
                                                let playerID = String(describing: ObjectIdentifier(player))
                                                let isPlaying = player.rate > 0
                                                Logger.caching.info("🛑 TRIM_PAUSE_PLAYER: Explicitly pausing base player \(playerID), was playing=\(isPlaying)")
                                                player.pause()
                                                player.rate = 0
                                            }

                                            // Get current audio session state for debugging
                                            let audioSession = AVAudioSession.sharedInstance()
                                            let category = audioSession.category.rawValue
                                            let mode = audioSession.mode.rawValue
                                            let isOtherPlaying = audioSession.isOtherAudioPlaying

                                            Logger.caching.info("📊 TRIM_AUDIO_STATE: Before trim init: category=\(category), mode=\(mode), otherPlaying=\(isOtherPlaying)")

                                            // Deactivate audio session to ensure clean state for trim view
                                            do {
                                                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                                                Logger.caching.info("📊 TRIM_AUDIO_RESET: Deactivated audio session to prepare for trim view")
                                            } catch {
                                                Logger.caching.error("📊 TRIM_AUDIO_ERROR: Failed to deactivate session: \(error.localizedDescription)")
                                            }

                                            // Longer delay to ensure trim view has time to fully initialize
                                            Logger.caching.info("⏰ TRIM_DELAY: Waiting to allow trim view to fully initialize")
                                            // Use a longer delay to ensure complete initialization and avoid resource contention
                                            try? await Task.sleep(for: .milliseconds(2500))

                                            // Log audio session state after delay
                                            let afterAudioSession = AVAudioSession.sharedInstance()
                                            let afterCategory = afterAudioSession.category.rawValue
                                            let afterMode = afterAudioSession.mode.rawValue
                                            let afterIsOtherPlaying = afterAudioSession.isOtherAudioPlaying

                                            Logger.caching.info("📊 TRIM_AUDIO_STATE: After delay: category=\(afterCategory), mode=\(afterMode), otherPlaying=\(afterIsOtherPlaying)")

                                            Logger.caching.info("🛑 PAUSE_OPERATIONS: Pausing background operations for trim view")
                                            await provider.pauseBackgroundOperations()

                                            // Log successful pause and final audio state
                                            Logger.caching.info("✅ BACKGROUND_OPERATIONS: Successfully paused")

                                            // Log if there are any active AVPlayers in the provider
                                            if let baseViewModel = provider as? BaseVideoViewModel {
                                                if let player = baseViewModel.player {
                                                    let playerID = String(describing: ObjectIdentifier(player))
                                                    let isPlaying = player.rate > 0
                                                    Logger.caching.info("🎮 TRIM_PLAYER_CHECK: Base player \(playerID) still exists, playing=\(isPlaying)")
                                                } else {
                                                    Logger.caching.info("🎮 TRIM_PLAYER_CHECK: Base player is nil")
                                                }
                                            }
                                        }
                                    }
                                    .onDisappear {
                                        // Resume all background operations when trim view is dismissed
                                        Task {
                                            // First get current audio session state for debugging
                                            let audioSession = AVAudioSession.sharedInstance()
                                            let category = audioSession.category.rawValue
                                            let mode = audioSession.mode.rawValue
                                            let isOtherPlaying = audioSession.isOtherAudioPlaying

                                            Logger.caching.info("📊 TRIM_AUDIO_STATE: On dismissal: category=\(category), mode=\(mode), otherPlaying=\(isOtherPlaying)")

                                            Logger.caching.info("▶️ RESUME_OPERATIONS: Resuming background operations after trim view")
                                            await provider.resumeBackgroundOperations()

                                            // Log if there are any active AVPlayers in the provider after resuming
                                            if let baseViewModel = provider as? BaseVideoViewModel {
                                                if let player = baseViewModel.player {
                                                    let playerID = String(describing: ObjectIdentifier(player))
                                                    let isPlaying = player.rate > 0
                                                    Logger.caching.info("🎮 TRIM_PLAYER_RESUME: Base player \(playerID) state after resume, playing=\(isPlaying)")
                                                } else {
                                                    Logger.caching.info("🎮 TRIM_PLAYER_RESUME: Base player is nil after resume")
                                                }
                                            }
                                        }
                                    }
                                }
                                Spacer()
                            }
                        }
                        .transition(.opacity)
                        .zIndex(100) // Ensure it's above all other content
                    }

                    // Saved identifier notification overlay
                    if viewState.showSavedNotification {
                        VStack {
                            SavedIdentifierOverlay(
                                title: viewState.savedIdentifierTitle,
                                presetName: viewState.savedPresetName,
                                isVisible: $viewState.showSavedNotification
                            )
                            .padding(.top, 50)

                            Spacer()
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(110) // Ensure it's above all other content
                    }
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