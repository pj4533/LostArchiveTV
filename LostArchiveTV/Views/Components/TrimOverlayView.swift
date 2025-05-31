//
//  TrimOverlayView.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 5/31/25.
//

import SwiftUI
import AVKit
import AVFoundation
import OSLog

struct TrimOverlayView<Provider: VideoProvider & ObservableObject>: View {
    @ObservedObject var provider: Provider
    @ObservedObject var viewState: PlayerViewState
    @Binding var downloadedVideoURL: URL?
    
    var body: some View {
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
                                downloadedVideoURL = url
                                viewState.trimStep = .trimming
                            } else {
                                // Failed download - dismiss everything
                                downloadedVideoURL = nil
                                viewState.trimStep = .none
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
                            handleTrimViewAppear(baseViewModel: baseViewModel)
                        }
                        .onDisappear {
                            handleTrimViewDisappear(baseViewModel: baseViewModel)
                        }
                    }
                    Spacer()
                }
            }
            .transition(.opacity)
            .zIndex(100) // Ensure it's above all other content
        }
    }
    
    private func handleTrimViewAppear(baseViewModel: BaseVideoViewModel) {
        // IMPORTANT: Give the trim view a longer delay to initialize
        Task {
            // First explicitly pause the current player to avoid conflicts
            if let player = baseViewModel.player {
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
            if let player = baseViewModel.player {
                let playerID = String(describing: ObjectIdentifier(player))
                let isPlaying = player.rate > 0
                Logger.caching.info("🎮 TRIM_PLAYER_CHECK: Base player \(playerID) still exists, playing=\(isPlaying)")
            } else {
                Logger.caching.info("🎮 TRIM_PLAYER_CHECK: Base player is nil")
            }
        }
    }
    
    private func handleTrimViewDisappear(baseViewModel: BaseVideoViewModel) {
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