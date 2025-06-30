import Foundation
import AVKit
import AVFoundation
import OSLog
import SwiftUI

@MainActor
class SearchViewModel: BaseVideoViewModel, VideoProvider, CacheableProvider {
    // Services - for CacheableProvider protocol
    private let searchManager: SearchManager
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
    
    // Alert state for unavailable content
    @Published var showingUnavailableAlert = false
    @Published var unavailableAlertTitle = ""
    
    // Reference to feed view model for pagination support
    weak var linkedFeedViewModel: SearchFeedViewModel?
    
    // Navigation state
    // Changed to internal with setter for extensions to access
    internal var currentIndex = 0
    @Published var currentResult: SearchResult?

    // Current cached video reference
    private var _currentCachedVideo: CachedVideo?
    
    // For video transition/swipe support
    var transitionManager: VideoTransitionManager? = VideoTransitionManager()
    
    // Task management for proper cancellation
    private var searchTask: Task<Void, Never>?
    
    // File count cache to avoid repeated API calls
    // Using dual approach: nonisolated storage for synchronous reads + Published for UI updates
    // Now stores Result to track both successful counts and content unavailable errors
    private nonisolated(unsafe) var _fileCountCache: [String: Result<Int, NetworkError>] = [:]
    @Published var fileCountCacheVersion: Int = 0
    
    // Track unavailable content separately for quick lookup
    private nonisolated(unsafe) var _unavailableContent: Set<String> = []
    @Published var unavailableContentVersion: Int = 0
    
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
        Task {
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
    
    // MARK: - File Count Cache Methods
    
    /// Get cached file count for an identifier
    /// - Parameter identifier: The archive identifier
    /// - Returns: The cached file count if available, nil otherwise
    nonisolated func getCachedFileCount(for identifier: String) -> Int? {
        guard let result = _fileCountCache[identifier] else { return nil }
        switch result {
        case .success(let count):
            return count
        case .failure:
            return nil
        }
    }
    
    /// Check if content is unavailable for an identifier
    /// - Parameter identifier: The archive identifier
    /// - Returns: True if the content is known to be unavailable
    nonisolated func isContentUnavailable(for identifier: String) -> Bool {
        return _unavailableContent.contains(identifier)
    }
    
    /// Fetch file count for an identifier and cache the result
    /// - Parameter identifier: The archive identifier
    /// - Returns: The file count, or nil if there was an error
    func fetchFileCount(for identifier: String) async -> Int? {
        Logger.caching.debug("🔍 DEBUG: fetchFileCount called for: \(identifier)")
        
        // Check cache first
        if let cachedResult = _fileCountCache[identifier] {
            switch cachedResult {
            case .success(let count):
                Logger.caching.info("🔍 DEBUG: File count cache hit for \(identifier): \(count)")
                return count
            case .failure(let error):
                Logger.caching.info("🔍 DEBUG: Cached error for \(identifier): \(error.localizedDescription)")
                return nil
            }
        }
        
        do {
            // Fetch metadata to calculate file count
            Logger.caching.info("🔍 DEBUG: Fetching metadata for file count calculation: \(identifier)")
            let metadata = try await archiveService.fetchMetadata(for: identifier)
            Logger.caching.debug("🔍 DEBUG: Got metadata with \(metadata.files.count) files")
            
            // Use the static method from VideoLoadingService to calculate file count
            let fileCount = VideoLoadingService.calculateFileCount(from: metadata)
            Logger.caching.debug("🔍 DEBUG: calculateFileCount returned: \(fileCount)")
            
            // Cache the successful result and trigger UI updates
            _fileCountCache[identifier] = .success(fileCount)
            fileCountCacheVersion += 1  // Trigger UI update through @Published
            Logger.caching.info("🔍 DEBUG: Cached file count for \(identifier): \(fileCount)")
            
            return fileCount
        } catch {
            Logger.caching.error("🔍 DEBUG: Failed to fetch file count for \(identifier): \(error.localizedDescription)")
            
            // Check if this is a content unavailable error
            if let networkError = error as? NetworkError,
               case .contentUnavailable = networkError {
                // Cache the error and mark as unavailable
                _fileCountCache[identifier] = .failure(networkError)
                _unavailableContent.insert(identifier)
                fileCountCacheVersion += 1
                unavailableContentVersion += 1
                Logger.caching.info("🔍 DEBUG: Marked content as unavailable for \(identifier)")
            }
            
            return nil
        }
    }
    
    /// Proactively fetch file counts for search results to improve UI responsiveness
    /// - Parameter results: The search results to fetch file counts for
    private func prefetchFileCounts(for results: [SearchResult]) async {
        Logger.caching.info("🔍 DEBUG: Starting prefetch of file counts for \(results.count) results")
        
        // Fetch file counts for the first 10 results (or all if less than 10)
        let prefetchCount = min(10, results.count)
        
        for i in 0..<prefetchCount {
            let identifier = results[i].identifier.identifier
            
            // Skip if already cached
            if _fileCountCache[identifier] != nil {
                continue
            }
            
            // Fetch file count
            let _ = await fetchFileCount(for: identifier)
            
            // Small delay to avoid overwhelming the server
            try? await Task.sleep(for: .milliseconds(100))
        }
        
        Logger.caching.info("🔍 DEBUG: Completed prefetch of file counts for first \(prefetchCount) results")
    }
    
    func search() async {
        guard !self.searchQuery.isEmpty else {
            searchResults = []
            return
        }
        
        // Clear file count cache and unavailable content when starting a new search
        _fileCountCache.removeAll()
        _unavailableContent.removeAll()
        fileCountCacheVersion += 1  // Trigger UI update
        unavailableContentVersion += 1
        Logger.caching.info("Cleared file count cache and unavailable content for new search")
        
        // Cancel any previously running search task
        searchTask?.cancel()
        
        // Create a new search task
        searchTask = Task {
            isSearching = true
            clearError()
            
            do {
                guard !Task.isCancelled else { return }
                
                Logger.caching.info("Performing search for query: \(self.searchQuery)")
                let results = try await searchManager.search(query: self.searchQuery, filter: searchFilter)
                
                // Check if task was cancelled during network operation
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    self.searchResults = results
                    
                    if !results.isEmpty {
                        Logger.caching.info("Search returned \(results.count) results")
                        currentIndex = 0
                        currentResult = results[0]
                        
                        // Proactively fetch file counts for the first few results to improve UI responsiveness
                        Task.detached(priority: .background) {
                            await self.prefetchFileCounts(for: results)
                        }
                    } else {
                        Logger.caching.info("Search returned no results")
                        errorMessage = "No results found"
                        currentResult = nil
                        player = nil
                    }
                    
                    isSearching = false
                }
            } catch {
                // Check if the error is due to task cancellation
                if Task.isCancelled {
                    Logger.network.info("Search task was cancelled")
                    await MainActor.run {
                        isSearching = false
                    }
                    return
                }
                
                await MainActor.run {
                    handleError(error)
                    Logger.network.error("Search failed: \(error.localizedDescription)")
                    isSearching = false
                }
            }
        }
    }
    
    func playVideoAt(index: Int) {
        guard index >= 0, index < searchResults.count else { return }
        
        let result = searchResults[index]
        
        // Check if content is unavailable before attempting to load
        if isContentUnavailable(for: result.identifier.identifier) {
            Logger.caching.info("SearchViewModel.playVideoAt: Content unavailable for \(result.identifier.identifier)")
            unavailableAlertTitle = result.title
            showingUnavailableAlert = true
            return
        }
        
        Logger.caching.info("SearchViewModel.playVideoAt: Playing video at index \(index)")
        isLoading = true
        currentIndex = index
        currentResult = searchResults[index]
        
        // Ensure the transition manager is initialized
        if transitionManager == nil {
            transitionManager = VideoTransitionManager()
        }
        
        Task {
            await loadVideo(for: searchResults[index].identifier)
            
            // Only show player if video loaded successfully (no error)
            if errorMessage == nil {
                // Start preloading of adjacent videos - this helps ensure smooth swipe transitions
                try? await Task.sleep(for: .seconds(0.5))
                await ensureVideosAreCached()
                
                isLoading = false
                showingPlayer = true
            } else {
                // Check if the error is content unavailable
                if let error = errorMessage, error.contains("no longer available") {
                    // Mark as unavailable and show alert
                    _unavailableContent.insert(result.identifier.identifier)
                    unavailableContentVersion += 1
                    
                    isLoading = false
                    unavailableAlertTitle = result.title
                    showingUnavailableAlert = true
                    clearError()
                } else {
                    // Video failed to load for other reasons, try loading the next video
                    isLoading = false
                    
                    // Move to next video and try loading it
                    if let nextVideo = await getNextVideo() {
                        // Update current result based on new index
                        currentResult = searchResults[currentIndex]
                        
                        // Try to play the next video
                        await loadVideo(for: nextVideo.archiveIdentifier)
                    }
                }
            }
        }
    }
    
    private func loadVideo(for identifier: ArchiveIdentifier) async {
        do {
            isLoading = true

            Logger.caching.info("Loading video for identifier: \(identifier.identifier)")

            // Create a CachedVideo from the search result
            let cachedVideo = try await createCachedVideo(for: identifier)

            // Store a reference to the cached video
            _currentCachedVideo = cachedVideo

            // Update totalFiles from cached video
            self.totalFiles = cachedVideo.totalFiles
            Logger.files.info("📊 SEARCH PLAYER: Updated totalFiles to \(cachedVideo.totalFiles) from CachedVideo")

            // Create player item and player
            let playerItem = AVPlayerItem(asset: cachedVideo.asset)
            let newPlayer = AVPlayer(playerItem: playerItem)

            // Set the player and seek to start position
            player = newPlayer

            // Seek to the specified position
            let startTime = CMTime(seconds: cachedVideo.startPosition, preferredTimescale: 600)
            await newPlayer.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)

            // Start playback
            newPlayer.play()

            // Update metadata properties
            currentIdentifier = identifier.identifier
            currentFilename = cachedVideo.mp4File.name
            if let result = searchResults.first(where: { $0.identifier.identifier == identifier.identifier }) {
                currentTitle = result.title
                currentDescription = result.description
                currentCollection = identifier.collection
            }

            
            isLoading = false
        } catch {
            handleError(error)
            Logger.caching.error("Failed to load video: \(error.localizedDescription)")
            isLoading = false
        }
    }
    
    // Method to load a video for a specific identifier
    internal func loadFreshRandomVideo(for identifier: ArchiveIdentifier) async throws -> (identifier: String, collection: String, title: String, description: String, filename: String, asset: AVAsset, startPosition: Double) {
        Logger.metadata.info("Loading video for specific identifier: \(identifier.identifier) from collection: \(identifier.collection)")
        
        let metadataStartTime = CFAbsoluteTimeGetCurrent()
        let metadata = try await archiveService.fetchMetadata(for: identifier.identifier)
        let metadataTime = CFAbsoluteTimeGetCurrent() - metadataStartTime
        Logger.network.info("Fetched metadata in \(String(format: "%.4f", metadataTime)) seconds")
        
        // Find MP4 file
        let mp4Files = await archiveService.findPlayableFiles(in: metadata)
        
        guard !mp4Files.isEmpty else {
            let error = "No MP4 file found in the archive"
            Logger.metadata.error("\(error)")
            throw NSError(domain: "VideoPlayerError", code: 1, userInfo: [NSLocalizedDescriptionKey: error])
        }
        
        // Select a file prioritizing longer durations
        guard let mp4File = await archiveService.selectFilePreferringLongerDurations(from: mp4Files) else {
            let error = "Failed to select file from available mp4Files"
            Logger.metadata.error("\(error)")
            throw NSError(domain: "VideoPlayerError", code: 1, userInfo: [NSLocalizedDescriptionKey: error])
        }
        
        guard let videoURL = await archiveService.getFileDownloadURL(for: mp4File, identifier: identifier.identifier) else {
            let error = "Could not create video URL"
            Logger.metadata.error("\(error)")
            throw NSError(domain: "VideoPlayerError", code: 2, userInfo: [NSLocalizedDescriptionKey: error])
        }
        
        // Create asset with optimized loading
        let assetStartTime = CFAbsoluteTimeGetCurrent()
        var options: [String: Any] = [:]
        if EnvironmentService.shared.hasArchiveCookie {
            let headers: [String: String] = [
               "Cookie": EnvironmentService.shared.archiveCookie
            ]
            options["AVURLAssetHTTPHeaderFieldsKey"] = headers
        }
        // Create an asset from the URL
        let asset = AVURLAsset(url: videoURL, options: options)
        Logger.videoPlayback.debug("Created AVURLAsset")
        
        // Set title and description from metadata
        let title = metadata.metadata?.title ?? identifier.identifier
        let description = metadata.metadata?.description ?? "Internet Archive video"
        let filename = mp4File.name
        
        // Get estimated duration from metadata
        let estimatedDuration = await archiveService.estimateDuration(fromFile: mp4File)
        
        // Use more conservative duration to avoid seeking too close to the end
        let safetyMargin = min(estimatedDuration * 0.2, 60.0)
        let maxStartTime = max(0, estimatedDuration - safetyMargin)
        let safeMaxStartTime = max(0, min(maxStartTime, estimatedDuration - 40))
        
        // If video is very short, start from beginning
        let randomStart = safeMaxStartTime > 10 ? Double.random(in: 0..<safeMaxStartTime) : 0
        
        // Log video duration and offset information in a single line for easy identification
        Logger.videoPlayback.info("VIDEO TIMING: Duration=\(String(format: "%.1f", estimatedDuration))s, Offset=\(String(format: "%.1f", randomStart))s (\(identifier.identifier))")
        
        let assetTime = CFAbsoluteTimeGetCurrent() - assetStartTime
        Logger.videoPlayback.info("Asset setup completed in \(String(format: "%.4f", assetTime)) seconds")
        
        return (
            identifier.identifier,
            identifier.collection,
            title,
            description,
            filename,
            asset,
            randomStart
        )
    }
    
    // NOTE: The getIdentifiersForGeneralCaching method has been moved to a single location at line 94
    // MARK: - CacheableProvider Protocol Implementation
    // See getIdentifiersForGeneralCaching() implementation above
    
    // NOTE: We no longer need to override ensureVideosAreCached
    // The base implementation now uses TransitionPreloadManager.ensureAllVideosCached()
    // which handles both general caching and transition caching in one call
}