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
    
    // New properties for tracking app initialization and cache status
    @Published var isInitializing = true
    @Published var cacheProgress: Double = 0.0
    @Published var cacheMessage = "Loading video library..."
    
    // Cache monitoring
    private var cacheMonitorTask: Task<Void, Never>?
    
    // Archive.org video identifiers
    private var identifiers: [String] = []
    
    // MARK: - Initialization and Cleanup
    init() {
        // Configure audio session for proper playback on all devices
        playbackManager.setupAudioSession()
        
        // Set initial state
        isInitializing = true
        
        // Load identifiers and start preloading videos when the ViewModel is initialized
        Task {
            // Load identifiers first - must complete before preloading
            await loadIdentifiers()
            
            // Only start preloading after identifiers are loaded
            if !identifiers.isEmpty {
                // Start monitoring cache progress
                monitorCacheProgress()
                
                // Begin preloading videos
                await ensureVideosAreCached()
                
                // After preloading is started, load the first video but don't show it yet
                // (it will be shown once initialization is complete)
                await loadRandomVideo(showImmediately: false)
            } else {
                Logger.caching.error("Cannot preload: identifiers not loaded properly")
                isInitializing = false
            }
        }
        
        // Configure logging
        Logger.videoPlayback.info("TikTok-style video player initialized with swipe interface")
    }
    
    // MARK: - Cache monitoring
    
    private func monitorCacheProgress() {
        cacheMonitorTask?.cancel()
        
        cacheMonitorTask = Task {
            var isFirstVideoLoaded = false
            
            while !Task.isCancelled && isInitializing {
                let cacheCount = await cacheManager.cacheCount()
                let maxCacheSize = await cacheManager.getMaxCacheSize()
                
                // Update progress
                self.cacheProgress = Double(cacheCount) / Double(maxCacheSize)
                
                // Update message based on current state
                if cacheCount == 0 {
                    self.cacheMessage = "Loading video library..."
                } else if !isFirstVideoLoaded {
                    self.cacheMessage = "Preparing first video..."
                    isFirstVideoLoaded = true
                    
                    // If the first video is loaded, complete initialization
                    // This allows the video to start playing immediately while cache continues filling
                    try? await Task.sleep(for: .seconds(0.5))
                    self.isInitializing = false
                    
                    // Don't cancel the monitoring task - let it continue in the background
                    break
                } else {
                    self.cacheMessage = "Preloading videos for smooth playback..."
                }
                
                // Check periodically to avoid overwhelming the system
                try? await Task.sleep(for: .seconds(0.2))
            }
            
            // Continue monitoring the cache in the background
            while !Task.isCancelled {
                let cacheCount = await cacheManager.cacheCount()
                let maxCacheSize = await cacheManager.getMaxCacheSize()
                
                // Update progress for any UI that might still be showing it
                self.cacheProgress = Double(cacheCount) / Double(maxCacheSize)
                
                // If cache is full, we can stop monitoring
                if cacheCount >= maxCacheSize {
                    self.cacheMonitorTask?.cancel()
                    break
                }
                
                // Check less frequently now that we're in the background
                try? await Task.sleep(for: .seconds(0.5))
            }
        }
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
            isInitializing = false
        }
    }
    
    func loadRandomVideo(showImmediately: Bool = true) async {
        let overallStartTime = CFAbsoluteTimeGetCurrent()
        Logger.videoPlayback.info("Starting to load random video for swipe interface")
        
        // Only update UI loading state if we're showing immediately
        if showImmediately {
            isLoading = true
            errorMessage = nil
        }
        
        // Ensure we have identifiers loaded
        if identifiers.isEmpty {
            Logger.metadata.warning("Attempting to load video but identifiers array is empty, loading identifiers first")
            await loadIdentifiers()
            
            // Check again after loading
            if identifiers.isEmpty {
                Logger.metadata.error("No identifiers available after explicit load attempt")
                errorMessage = "No identifiers available. Make sure avgeeks_identifiers.json is in the app bundle."
                isLoading = false
                isInitializing = false
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
                
                // Always start playback of the first video
                // The loading screen will stay up until isInitializing becomes false
                self?.playbackManager.play()
                
                // Monitor buffer status
                if let playerItem = self?.playbackManager.player?.currentItem {
                    Task {
                        await self?.playbackManager.monitorBufferStatus(for: playerItem)
                    }
                }
            }
            
            // Only update loading state if we're showing immediately
            if showImmediately {
                isLoading = false
            }
            
            // Start preloading the next video if needed
            await ensureVideosAreCached()
            
            let overallTime = CFAbsoluteTimeGetCurrent() - overallStartTime
            Logger.videoPlayback.info("Total video load time: \(overallTime.formatted(.number.precision(.fractionLength(4)))) seconds")
            
        } catch {
            Logger.videoPlayback.error("Failed to load video: \(error.localizedDescription)")
            
            if showImmediately {
                isLoading = false
                errorMessage = "Error loading video: \(error.localizedDescription)"
            }
            
            // Always exit initialization mode on error to prevent being stuck in loading
            isInitializing = false
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
        cacheMonitorTask?.cancel()
        
        Task {
            await preloadService.cancelPreloading()
            await cacheManager.clearCache()
        }
        
        // Player cleanup is handled by playbackManager
        playbackManager.cleanupPlayer()
    }
}