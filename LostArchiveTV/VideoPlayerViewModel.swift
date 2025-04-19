//
//  VideoPlayerViewModel.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import SwiftUI
import AVKit
import AVFoundation
import OSLog

@MainActor
class VideoPlayerViewModel: ObservableObject {
    // Services
    private let archiveService = ArchiveService()
    private let cacheManager = VideoCacheManager()
    private let preloadService = PreloadService()
    private let playbackManager = VideoPlaybackManager()
    private lazy var videoLoadingService = VideoLoadingService(
        archiveService: archiveService,
        cacheManager: cacheManager
    )
    
    // Published properties - these are the public interface of our ViewModel
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentIdentifier: String?
    @Published var currentTitle: String?
    @Published var currentDescription: String?
    
    // Archive.org video identifiers
    private var identifiers: [String] = []
    
    // MARK: - Initialization and Cleanup
    init() {
        // Configure audio session for proper playback on all devices
        playbackManager.setupAudioSession()
        
        // Load identifiers and start preloading videos when the ViewModel is initialized
        Task {
            // Load identifiers first - must complete before preloading
            await loadIdentifiers()
            
            // Only start preloading after identifiers are loaded
            if !identifiers.isEmpty {
                await ensureVideosAreCached()
            } else {
                Logger.caching.error("Cannot preload: identifiers not loaded properly")
            }
        }
        
        // Configure logging
        Logger.videoPlayback.info("TikTok-style video player initialized with swipe interface")
    }
    
    // MARK: - Swipe Interface Support
    
    /// Prepares the player for swiping by ensuring multiple videos are cached
    func prepareForSwipe() {
        Logger.videoPlayback.debug("Preparing for swipe interactions")
        Task {
            await ensureVideosAreCached()
        }
    }
    
    /// Handles the completion of a swipe gesture
    func handleSwipeCompletion() {
        Logger.videoPlayback.info("Swipe gesture completed, loading next video")
        Task {
            await loadRandomVideo()
        }
    }
    
    // MARK: - Public Interface
    
    var player: AVPlayer? {
        playbackManager.player
    }
    
    var videoDuration: Double {
        playbackManager.videoDuration
    }
    
    // MARK: - Video Loading
    
    private func loadIdentifiers() async {
        do {
            identifiers = try await videoLoadingService.loadIdentifiers()
            Logger.metadata.info("Successfully loaded \(self.identifiers.count) identifiers")
        } catch {
            Logger.metadata.error("Failed to load identifiers: \(error.localizedDescription)")
            self.errorMessage = "Failed to load video identifiers: \(error.localizedDescription)"
        }
    }
    
    func loadRandomVideo() async {
        let overallStartTime = CFAbsoluteTimeGetCurrent()
        Logger.videoPlayback.info("Starting to load random video for swipe interface")
        isLoading = true
        errorMessage = nil
        
        // Ensure we have identifiers loaded
        if identifiers.isEmpty {
            Logger.metadata.warning("Attempting to load video but identifiers array is empty, loading identifiers first")
            await loadIdentifiers()
            
            // Check again after loading
            if identifiers.isEmpty {
                Logger.metadata.error("No identifiers available after explicit load attempt")
                errorMessage = "No identifiers available. Make sure avgeeks_identifiers.json is in the app bundle."
                isLoading = false
                return
            }
        }
        
        // Clean up existing player
        playbackManager.cleanupPlayer()
        
        // Pre-emptively start caching next videos for smooth swipes
        Task {
            await ensureVideosAreCached()
        }
        
        do {
            // Load a random video using our service
            let videoInfo = try await videoLoadingService.loadRandomVideo()
            
            // Set the current video info
            currentIdentifier = videoInfo.identifier
            currentTitle = videoInfo.title
            currentDescription = videoInfo.description
            
            // Setup player with the asset
            playbackManager.setupPlayer(with: videoInfo.asset)
            
            // Create the start time
            let startTime = CMTime(seconds: videoInfo.startPosition, preferredTimescale: 600)
            Logger.videoPlayback.info("Starting playback at time offset: \(videoInfo.startPosition.formatted(.number.precision(.fractionLength(2)))) seconds")
            
            let seekStartTime = CFAbsoluteTimeGetCurrent()
            playbackManager.seek(to: startTime) { [weak self] finished in
                let seekTime = CFAbsoluteTimeGetCurrent() - seekStartTime
                Logger.videoPlayback.info("Video seek completed in \(seekTime.formatted(.number.precision(.fractionLength(4)))) seconds")
                
                // Start playback
                self?.playbackManager.play()
                
                // Monitor buffer status
                if let playerItem = self?.playbackManager.player?.currentItem {
                    Task {
                        await self?.playbackManager.monitorBufferStatus(for: playerItem)
                    }
                }
            }
            
            isLoading = false
            
            // Start preloading the next video if needed
            await ensureVideosAreCached()
            
            let overallTime = CFAbsoluteTimeGetCurrent() - overallStartTime
            Logger.videoPlayback.info("Total video load time: \(overallTime.formatted(.number.precision(.fractionLength(4)))) seconds")
            
        } catch {
            Logger.videoPlayback.error("Failed to load video: \(error.localizedDescription)")
            isLoading = false
            errorMessage = "Error loading video: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Caching
    
    private func ensureVideosAreCached() async {
        await preloadService.ensureVideosAreCached(
            cacheManager: cacheManager,
            archiveService: archiveService,
            identifiers: identifiers
        )
    }
    
    deinit {
        // Cancel any ongoing tasks
        Task {
            await preloadService.cancelPreloading()
            await cacheManager.clearCache()
        }
        
        // Player cleanup is handled by playbackManager
        playbackManager.cleanupPlayer()
    }
}