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
        
        // CHANGED: Load identifiers and immediately start loading first video
        Task {
            // Load identifiers first - must complete before loading any video
            await loadIdentifiers()
            
            // CRITICAL CHANGE: Directly load first video without waiting for cache
            if !identifiers.isEmpty {
                // Start loading first video immediately
                Task {
                    // Show the first video as soon as it's loaded
                    await loadFirstVideoDirectly()
                }
                
                // Start cache monitoring in parallel, but don't wait for it
                Task {
                    monitorCacheProgress()
                }
                
                // Start preloading in parallel, but don't block first video
                Task {
                    // This will now run in the background and not block first video
                    await ensureVideosAreCached()
                }
            } else {
                Logger.caching.error("Cannot load: identifiers not loaded properly")
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
            Logger.caching.info("🔄 CACHE: Monitor task started (background)")
            
            // Not crucial for first video anymore - run in background
            var monitorCycles = 0
            
            while !Task.isCancelled {
                monitorCycles += 1
                let cacheCount = await cacheManager.cacheCount()
                let hasPlayer = self.player != nil
                let currentVideoID = self.currentIdentifier ?? "none"
                
                Logger.caching.info("📊 CACHE: Monitor cycle \(monitorCycles) | Size: \(cacheCount) | Player: \(hasPlayer ? "ACTIVE" : "none") | Video: \(currentVideoID)")
                
                // If cache has videos, ensure preloading is active
                if cacheCount >= 1 && isInitializing {
                    // This is now a backup in case direct loading fails
                    Logger.caching.info("📊 CACHE: Backup initialization exit - cache ready")
                    self.isInitializing = false
                }
                
                // Reduced polling frequency since this is not critical path
                try? await Task.sleep(for: .seconds(0.5))
                
                // Exit if we've been monitoring too long or initialization is complete
                if !isInitializing || monitorCycles >= 20 {
                    Logger.caching.info("📊 CACHE: Exiting monitor - initialization complete or timeout reached")
                    break
                }
            }
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
        
        // Create cached video with current totalFiles value
        let cachedVideo = CachedVideo(
            identifier: identifier,
            collection: collection,
            metadata: metadata,
            mp4File: mp4File,
            videoURL: videoURL,
            asset: asset,
            playerItem: playerItem,
            startPosition: currentTime,
            addedToFavoritesAt: nil,
            totalFiles: self.totalFiles
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