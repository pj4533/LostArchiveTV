import Foundation
import AVKit
import AVFoundation
import OSLog
import SwiftUI

@MainActor
class SearchViewModel: BaseVideoViewModel, VideoProvider, CacheableProvider {
    // Services - for CacheableProvider protocol
    let searchManager: SearchManager
    internal let videoLoadingService: VideoLoadingService
    let archiveService = ArchiveService()
    let cacheManager = VideoCacheManager()
    let cacheService = VideoCacheService()
    internal let favoritesManager: FavoritesManager
    
    // Search state
    @Published var searchQuery = ""
    @Published var searchResults: [SearchResult] = []
    @Published var searchFilter = SearchFilter()
    @Published var isSearching = false
    @Published var showingPlayer = false
    
    // Reference to feed view model for pagination support
    weak var linkedFeedViewModel: SearchFeedViewModel?
    
    // Navigation state
    // Changed to internal with setter for extensions to access
    internal var currentIndex = 0
    @Published var currentResult: SearchResult?

    // Current cached video reference
    internal var _currentCachedVideo: CachedVideo?
    
    // For video transition/swipe support
    var transitionManager: VideoTransitionManager? = VideoTransitionManager()
    
    // Task management for proper cancellation
    internal var searchTask: Task<Void, Never>?
    
    // File count cache to avoid repeated API calls
    // Using dual approach: nonisolated storage for synchronous reads + Published for UI updates
    internal nonisolated(unsafe) var _fileCountCache: [String: Int] = [:]
    @Published var fileCountCacheVersion: Int = 0
    
    // MARK: - VideoControlProvider Protocol Overrides
    
    /// Checks if the current video is a favorite
    override var isFavorite: Bool {
        guard let identifier = currentIdentifier, let collection = currentCollection else {
            return false
        }
        
        let _ = ArchiveIdentifier(identifier: identifier, collection: collection)
        let dummyVideo = CachedVideo(
            identifier: identifier,
            collection: collection,
            metadata: ArchiveMetadata(files: [], metadata: nil),
            mp4File: ArchiveFile(name: "", format: "", size: "", length: nil),
            videoURL: URL(string: "about:blank")!,
            asset: AVURLAsset(url: URL(string: "about:blank")!),
            startPosition: 0,
            addedToFavoritesAt: nil,
            totalFiles: 1
        )
        
        return favoritesManager.isFavorite(dummyVideo)
    }
    
    /// Toggle favorite status of the current video
    override func toggleFavorite() {
        Task { @MainActor in
            if let cachedVideo = await createCachedVideoFromCurrentState() {
                favoritesManager.toggleFavorite(cachedVideo)
            }
        }
    }
    
    init(
        searchManager: SearchManager = SearchManager(),
        videoLoadingService: VideoLoadingService = VideoLoadingService(
            archiveService: ArchiveService(),
            cacheManager: VideoCacheManager()
        ),
        favoritesManager: FavoritesManager = FavoritesManager()
    ) {
        self.searchManager = searchManager
        self.videoLoadingService = videoLoadingService
        self.favoritesManager = favoritesManager
        
        super.init()
    }
    
    // MARK: - CacheableProvider Protocol
    
    // NOTE: We don't need to override ensureVideosAreCached() anymore
    // The base implementation now uses TransitionPreloadManager.ensureAllCaching()
    // which handles both general caching and transition caching in one call
    
    /// Returns identifiers to be used for caching
    /// - Returns: Archive identifiers from current search results
    func getIdentifiersForGeneralCaching() -> [ArchiveIdentifier] {
        guard !searchResults.isEmpty else { return [] }
        
        var identifiers: [ArchiveIdentifier] = []
        
        // Add current result and next few results
        let startIndex = currentIndex
        let endIndex = min(startIndex + 3, searchResults.count)
        
        for i in startIndex..<endIndex {
            identifiers.append(searchResults[i].identifier)
        }
        
        return identifiers
    }
    
    /// Cleanup resources when the view disappears
    override func cleanup() {
        Logger.network.info("SearchViewModel cleanup - cancelling all tasks")
        
        // Cancel search task
        searchTask?.cancel()
        searchTask = nil
        
        // Cleanup playback is now handled in the parent class
        // since pausePlayback requires async
        
        // Call the parent class cleanup
        super.cleanup()
    }
    
    // Extension methods are defined in separate files:
    // - SearchViewModel+Search.swift
    // - SearchViewModel+FileCount.swift
    // - SearchViewModel+VideoLoading.swift
    
    // NOTE: The getIdentifiersForGeneralCaching method has been moved to a single location at line 94
    // MARK: - CacheableProvider Protocol Implementation
    // See getIdentifiersForGeneralCaching() implementation above
    
    // NOTE: We no longer need to override ensureVideosAreCached
    // The base implementation now uses TransitionPreloadManager.ensureAllVideosCached()
    // which handles both general caching and transition caching in one call
}