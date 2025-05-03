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
class VideoPlayerViewModel: BaseVideoViewModel, VideoProvider, CacheableProvider {
    // Services
    let archiveService = ArchiveService()
    let cacheManager = VideoCacheManager()
    internal let preloadService = PreloadService() // Changed to internal for extension access
    internal lazy var videoLoadingService = VideoLoadingService(
        archiveService: archiveService,
        cacheManager: cacheManager
    )
    
    // Favorites manager
    let favoritesManager: FavoritesManager
    
    // App initialization tracking
    @Published var isInitializing = true
    
    // Cache monitoring
    private var cacheMonitorTask: Task<Void, Never>?
    
    // Archive.org video identifiers
    internal var identifiers: [ArchiveIdentifier] = [] // Changed to internal for extension access
    
    // Current cached video reference for favorites
    internal var _currentCachedVideo: CachedVideo? // Changed to internal for extension access
    
    // History tracking - uses the history manager
    private let historyManager = VideoHistoryManager()
    
    // Transition manager for swiping and preloading - required by VideoProvider
    var transitionManager: VideoTransitionManager? = VideoTransitionManager()
    
    // MARK: - VideoControlProvider Protocol Overrides
    
    override var isFavorite: Bool {
        if let currentVideo = _currentCachedVideo, currentVideo.identifier == currentIdentifier {
            return favoritesManager.isFavorite(currentVideo)
        } else if let identifier = currentIdentifier {
            return favoritesManager.isFavoriteIdentifier(identifier)
        }
        return false
    }
    
    override func toggleFavorite() {
        guard let currentVideo = _currentCachedVideo else { return }
        
        Logger.metadata.info("Toggling favorite status for video: \(currentVideo.identifier)")
        favoritesManager.toggleFavorite(currentVideo)
        objectWillChange.send()
    }
    
    // MARK: - Initialization and Cleanup
    override init() {
        // This empty init is needed to satisfy the compiler
        // We'll use the designated init instead
        fatalError("Use init(favoritesManager:) instead")
    }
    
    init(favoritesManager: FavoritesManager) {
        self.favoritesManager = favoritesManager
        
        // Call base class init
        super.init()
        
        // Set initial state
        isInitializing = true
        
        // Load identifiers and start preloading videos when the ViewModel is initialized
        Task {
            // Load identifiers first - must complete before preloading
            await loadIdentifiers()
            
            // Only start preloading after identifiers are loaded
            if !identifiers.isEmpty {
                // Start monitoring cache progress
                Logger.caching.info("Starting cache monitoring")
                monitorCacheProgress()
                
                // Begin preloading videos
                Logger.caching.info("Starting video preloading")
                await ensureVideosAreCached()
                
                // After preloading is started, load the first video but don't show it yet
                // (it will be shown once initialization is complete)
                Logger.caching.info("Loading initial random video")
                await loadRandomVideo(showImmediately: false)
                
                // IMPORTANT: Check if we have a player but initialization is still active
                // This handles the case where loadRandomVideo succeeds but cache monitoring hasn't caught up
                if self.player != nil && isInitializing {
                    Logger.caching.info("Video loaded and player exists, but initialization state not updated - forcing update")
                    isInitializing = false
                }
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
            Logger.caching.info("🔄 INIT: Cache monitor task started")
            // Track how many monitoring cycles we've performed
            var monitorCycles = 0
            var playerCheckPerformed = false
            
            // Wait until we have at least 1 video cached to begin playback
            while !Task.isCancelled && isInitializing {
                monitorCycles += 1
                let cacheCount = await cacheManager.cacheCount() 
                
                // Get player/video status for detailed logging
                let hasPlayer = self.player != nil
                let playerStatus = hasPlayer ? "ACTIVE" : "none"
                let currentVideoID = self.currentIdentifier ?? "none"
                
                Logger.caching.info("📊 INIT: Monitor cycle \(monitorCycles) | Cache size: \(cacheCount) | Initializing: \(self.isInitializing) | Player: \(playerStatus) | Current video: \(currentVideoID)")
                
                if cacheCount >= 1 {
                    // Exit initialization mode once we have at least one video ready
                    try? await Task.sleep(for: .seconds(0.2))
                    self.isInitializing = false
                    Logger.caching.info("✅ INIT: Initial cache ready with \(cacheCount) videos - exiting initialization")
                    break
                }
                
                // CRITICAL FIX: If no videos in cache but we already have an active player
                // or if we've been waiting for too long (10 seconds), exit initialization
                if monitorCycles >= 10 || (!playerCheckPerformed && self.player != nil) {
                    playerCheckPerformed = true
                    if self.player != nil {
                        Logger.caching.info("🚨 INIT: Player exists but cache is empty (video ID: \(currentVideoID)). Exiting initialization state.")
                        self.isInitializing = false
                        break
                    }
                }
                
                // If we've been stuck for a long time (50 cycles = ~10 seconds), force exit initialization
                if monitorCycles >= 50 {
                    Logger.caching.error("⚠️ INIT: Forced exit from initialization after \(monitorCycles) monitoring cycles")
                    self.isInitializing = false
                    break
                }
                
                try? await Task.sleep(for: .seconds(0.2))
            }
            Logger.caching.info("🏁 INIT: Cache monitor task completed - initialization finished")
        }
    }
    
    // MARK: - VideoProvider Protocol - History Management
    
    // Add a video to history (at the end)
    func addVideoToHistory(_ video: CachedVideo) {
        historyManager.addVideo(video)
    }
    
    // Get previous video from history - changes the current index
    func getPreviousVideo() async -> CachedVideo? {
        return historyManager.getPreviousVideo()
    }
    
    // Get next video from history - changes the current index
    func getNextVideo() async -> CachedVideo? {
        return historyManager.getNextVideo()
    }
    
    // Peek at previous video without changing the index - for preloading
    func peekPreviousVideo() async -> CachedVideo? {
        return historyManager.peekPreviousVideo()
    }
    
    // Peek at next video without changing the index - for preloading
    func peekNextVideo() async -> CachedVideo? {
        return historyManager.peekNextVideo()
    }
    
    // Check if we're at the end of history
    func isAtEndOfHistory() -> Bool {
        return historyManager.isAtEnd()
    }
    
    // Default implementation for main video player
    // Main feed doesn't need paging as it loads random videos
    func loadMoreItemsIfNeeded() async -> Bool {
        // Main player doesn't need to load more items as it plays random videos
        return false
    }
    
    // Update to next video - for VideoPlayerViewModel, historyManager already handles this
    func updateToNextVideo() {
        // For the main player, we don't need to do anything as the history manager maintains the state
        Logger.caching.info("VideoPlayerViewModel.updateToNextVideo called - using history manager")
        // Will use getNextVideo when needed
    }
    
    // Update to previous video - for VideoPlayerViewModel, historyManager already handles this
    func updateToPreviousVideo() {
        // For the main player, we don't need to do anything as the history manager maintains the state
        Logger.caching.info("VideoPlayerViewModel.updateToPreviousVideo called - using history manager")
        // Will use getPreviousVideo when needed
    }
    
    // MARK: - CacheableProvider Protocol
    
    /// Returns the list of identifiers for general caching
    /// For the main player, this is all available identifiers
    func getIdentifiersForGeneralCaching() -> [ArchiveIdentifier] {
        return identifiers
    }
    
    // MARK: - CacheableProvider Protocol
    
    // NOTE: We don't need to override ensureVideosAreCached() anymore
    // The base implementation now uses TransitionPreloadManager.ensureAllCaching()
    // which handles both general caching and transition caching in one call
    
    // MARK: - Video state management
    
    func createCachedVideoFromCurrentState() async -> CachedVideo? {
        guard let identifier = currentIdentifier,
              let collection = currentCollection,
              let title = currentTitle,
              let description = currentDescription,
              let videoURL = playbackManager.currentVideoURL,
              let playerItem = playbackManager.player?.currentItem,
              let asset = playerItem.asset as? AVURLAsset else {
            Logger.caching.error("Could not create cached video from current state: missing required properties")
            return nil
        }
        
        // Create a simplified metadata object with just title and description
        let metadata = ArchiveMetadata(
            files: [], 
            metadata: ItemMetadata(
                identifier: identifier,
                title: title, 
                description: description
            )
        )
        
        // Create a basic MP4 file representation
        let mp4File = ArchiveFile(
            name: identifier, 
            format: "h.264", 
            size: "", 
            length: nil
        )
        
        // Get the current position
        let currentTime = playbackManager.player?.currentTime().seconds ?? 0
        
        // Create cached video
        let cachedVideo = CachedVideo(
            identifier: identifier,
            collection: collection,
            metadata: metadata,
            mp4File: mp4File,
            videoURL: videoURL,
            asset: asset,
            playerItem: playerItem,
            startPosition: currentTime,
            addedToFavoritesAt: nil
        )
        
        return cachedVideo
    }
    
    deinit {
        // Cancel any ongoing tasks
        cacheMonitorTask?.cancel()
        
        Task {
            await preloadService.cancelPreloading()
            await cacheManager.clearCache()
            
            // Player cleanup is handled by parent class
            // Must use MainActor since the cleanup() method is @MainActor
            await MainActor.run {
                self.playbackManager.cleanupPlayer()
            }
        }
    }
}