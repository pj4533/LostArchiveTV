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
    let archiveService = ArchiveService()
    let cacheManager = VideoCacheManager()
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
    @Published var currentCollection: String?
    @Published var currentTitle: String?
    @Published var currentDescription: String?
    
    // New properties for tracking app initialization and cache status
    @Published var isInitializing = true
    @Published var cacheProgress: Double = 0.0
    @Published var cacheMessage = "Loading video library..."
    
    // Cache monitoring
    private var cacheMonitorTask: Task<Void, Never>?
    
    // Archive.org video identifiers
    private var identifiers: [ArchiveIdentifier] = []
    
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
            // Wait until we have at least 2 videos cached (bare minimum for swiping experience)
            while !Task.isCancelled && isInitializing {
                let cacheCount = await cacheManager.cacheCount() 
                let maxCacheSize = await cacheManager.getMaxCacheSize()
                
                // Update progress for loading screen
                self.cacheProgress = Double(cacheCount) / Double(maxCacheSize)
                
                // Update message based on progress
                if cacheCount == 0 {
                    self.cacheMessage = "Loading video library..."
                } else if cacheCount == 1 {
                    self.cacheMessage = "Preparing for swiping..."
                } else if cacheCount >= 2 {
                    // Once we have at least 2 videos, we can start playing
                    self.cacheMessage = "Ready for playback!"
                    try? await Task.sleep(for: .seconds(0.2))
                    
                    // Exit initialization mode now that we're ready
                    self.isInitializing = false
                    Logger.caching.info("Initial cache ready with \(cacheCount) videos - beginning playback")
                    break
                }
                
                try? await Task.sleep(for: .seconds(0.2))
            }
            
            // After initialization, we can stop the monitoring task
            // The cache will be maintained by the SwipeableVideoView when videos are played
            // and by calls to ensureVideosAreCached() when videos are removed
        }
    }
    
    // MARK: - Public Interface
    
    var player: AVPlayer? {
        get { playbackManager.player }
        set {
            if let newPlayer = newValue {
                // Use the player directly instead of creating a new one from asset
                playbackManager.useExistingPlayer(newPlayer)
            } else {
                playbackManager.cleanupPlayer()
            }
        }
    }
    
    var videoDuration: Double {
        playbackManager.videoDuration
    }
    
    // MARK: - Video trimming
    
    var currentVideoURL: URL? {
        playbackManager.currentVideoURL
    }
    
    var currentVideoTime: CMTime? {
        playbackManager.currentTimeAsCMTime
    }
    
    var currentVideoDuration: CMTime? {
        playbackManager.durationAsCMTime
    }
    
    func pausePlayback() {
        Logger.videoPlayback.debug("Pausing playback for trimming")
        playbackManager.pause()
    }
    
    func resumePlayback() {
        Logger.videoPlayback.debug("Resuming playback after trimming")
        playbackManager.play()
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
                errorMessage = "No identifiers available. Make sure the identifiers.sqlite database is in the app bundle."
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
            currentCollection = videoInfo.collection
            currentTitle = videoInfo.title
            currentDescription = videoInfo.description
            
            // Create a player with the seek position already applied
            let player = AVPlayer(playerItem: AVPlayerItem(asset: videoInfo.asset))
            let startTime = CMTime(seconds: videoInfo.startPosition, preferredTimescale: 600)
            
            // Log consistent video timing information when using from cache
            Logger.videoPlayback.info("VIDEO TIMING (PLAYING): Duration=\(self.playbackManager.videoDuration.formatted(.number.precision(.fractionLength(1))))s, Offset=\(videoInfo.startPosition.formatted(.number.precision(.fractionLength(1))))s (\(videoInfo.identifier))")
            
            // Seek to the correct position before we set it as the current player
            let seekStartTime = CFAbsoluteTimeGetCurrent()
            await player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
            let seekTime = CFAbsoluteTimeGetCurrent() - seekStartTime
            Logger.videoPlayback.info("Video seek completed in \(seekTime.formatted(.number.precision(.fractionLength(4)))) seconds")
            
            // Now set the player with the correct position already set
            // This will also extract and store the URL internally
            playbackManager.useExistingPlayer(player)
            
            // Always start playback of the video
            playbackManager.play()
            
            // Monitor buffer status
            if let playerItem = playbackManager.player?.currentItem {
                Task {
                    await playbackManager.monitorBufferStatus(for: playerItem)
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
    
    // MARK: - Caching and Video Trimming
    
    func ensureVideosAreCached() async {
        await preloadService.ensureVideosAreCached(
            cacheManager: cacheManager,
            archiveService: archiveService,
            identifiers: identifiers
        )
    }
    
    // MARK: - Video download state management
    
    func setLoading(_ loading: Bool) {
        isLoading = loading
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