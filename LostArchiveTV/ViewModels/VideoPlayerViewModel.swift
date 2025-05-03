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
class VideoPlayerViewModel: BaseVideoViewModel, VideoProvider {
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
            // Wait until we have at least 1 video cached to begin playback
            while !Task.isCancelled && isInitializing {
                let cacheCount = await cacheManager.cacheCount() 
                
                if cacheCount >= 1 {
                    // Exit initialization mode once we have at least one video ready
                    try? await Task.sleep(for: .seconds(0.2))
                    self.isInitializing = false
                    Logger.caching.info("Initial cache ready with \(cacheCount) videos - beginning playback")
                    break
                }
                
                try? await Task.sleep(for: .seconds(0.2))
            }
        }
    }
    
    // MARK: - VideoProvider Protocol - History Management
    
    // Add a video to history (at the end)
    func addVideoToHistory(_ video: CachedVideo) {
        historyManager.addVideo(video)
    }
    
    // Get previous video from history
    func getPreviousVideo() async -> CachedVideo? {
        return historyManager.getPreviousVideo()
    }
    
    // Get next video from history (or nil if we need a new one)
    func getNextVideo() async -> CachedVideo? {
        return historyManager.getNextVideo()
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