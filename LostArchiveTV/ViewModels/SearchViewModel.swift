import Foundation
import AVKit
import AVFoundation
import OSLog
import SwiftUI

@MainActor
class SearchViewModel: BaseVideoViewModel, VideoProvider {
    // Services
    private let searchManager: SearchManager
    private let videoLoadingService: VideoLoadingService
    private let archiveService = ArchiveService()
    private let favoritesManager: FavoritesManager
    
    // Search state
    @Published var searchQuery = ""
    @Published var searchResults: [SearchResult] = []
    @Published var searchFilter = SearchFilter()
    @Published var isSearching = false
    @Published var showingPlayer = false
    
    // Navigation state
    private(set) var currentIndex = 0
    @Published var currentResult: SearchResult?
    
    // For video transition/swipe support
    var transitionManager = VideoTransitionManager()
    
    // Task management for proper cancellation
    private var searchTask: Task<Void, Never>?
    
    // MARK: - VideoControlProvider Protocol Overrides
    
    /// Checks if the current video is a favorite
    override var isFavorite: Bool {
        guard let identifier = currentIdentifier, let collection = currentCollection else {
            return false
        }
        
        let archiveIdentifier = ArchiveIdentifier(identifier: identifier, collection: collection)
        let dummyVideo = CachedVideo(
            identifier: identifier,
            collection: collection,
            metadata: ArchiveMetadata(files: [], metadata: nil),
            mp4File: ArchiveFile(name: "", format: "", size: "", length: nil),
            videoURL: URL(string: "about:blank")!,
            asset: AVURLAsset(url: URL(string: "about:blank")!),
            playerItem: AVPlayerItem(asset: AVURLAsset(url: URL(string: "about:blank")!)),
            startPosition: 0,
            addedToFavoritesAt: nil
        )
        
        return favoritesManager.isFavorite(dummyVideo)
    }
    
    /// Toggle favorite status of the current video
    override func toggleFavorite() {
        Task {
            if let cachedVideo = await createCachedVideoFromCurrentState() {
                favoritesManager.toggleFavorite(cachedVideo)
                // Force UI refresh
                objectWillChange.send()
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
    
    /// Cleanup resources when the view disappears
    override func cleanup() {
        Logger.network.info("SearchViewModel cleanup - cancelling all tasks")
        
        // Cancel search task
        searchTask?.cancel()
        searchTask = nil
        
        // Cleanup playback
        if isPlaying {
            pausePlayback()
        }
        
        // Call the parent class cleanup
        super.cleanup()
    }
    
    func search() async {
        guard !self.searchQuery.isEmpty else {
            searchResults = []
            return
        }
        
        // Cancel any previously running search task
        searchTask?.cancel()
        
        // Create a new search task
        searchTask = Task {
            isSearching = true
            errorMessage = nil
            
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
                    errorMessage = "Search failed: \(error.localizedDescription)"
                    Logger.network.error("Search failed: \(error.localizedDescription)")
                    isSearching = false
                }
            }
        }
    }
    
    func playVideoAt(index: Int) {
        guard index >= 0, index < searchResults.count else { return }
        
        Logger.caching.info("SearchViewModel.playVideoAt: Playing video at index \(index)")
        isLoading = true
        currentIndex = index
        currentResult = searchResults[index]
        
        Task {
            await loadVideo(for: searchResults[index].identifier)
            
            // Start preloading of adjacent videos - this helps ensure smooth swipe transitions
            try? await Task.sleep(for: .seconds(0.5))
            await ensureVideosAreCached()
            
            isLoading = false
            showingPlayer = true
        }
    }
    
    private func loadVideo(for identifier: ArchiveIdentifier) async {
        do {
            isLoading = true
            
            Logger.caching.info("Loading video for identifier: \(identifier.identifier)")
            
            // Let's convert this to the format that ArchiveService would return
            let videoInfo = try await self.loadFreshRandomVideo(for: identifier)
            
            // Create player item and player
            let playerItem = AVPlayerItem(asset: videoInfo.asset)
            let newPlayer = AVPlayer(playerItem: playerItem)
            
            // Set the player and seek to start position
            player = newPlayer
            
            // Seek to the specified position
            let startTime = CMTime(seconds: videoInfo.startPosition, preferredTimescale: 600)
            await newPlayer.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
            
            // Start playback
            newPlayer.play()
            
            // Update metadata properties
            currentIdentifier = identifier.identifier
            if let result = searchResults.first(where: { $0.identifier.identifier == identifier.identifier }) {
                currentTitle = result.title
                currentDescription = result.description
                currentCollection = identifier.collection
            }
            
            isLoading = false
        } catch {
            errorMessage = "Failed to load video: \(error.localizedDescription)"
            Logger.caching.error("Failed to load video: \(error.localizedDescription)")
            isLoading = false
        }
    }
    
    // Method to load a video for a specific identifier
    private func loadFreshRandomVideo(for identifier: ArchiveIdentifier) async throws -> (identifier: String, collection: String, title: String, description: String, asset: AVAsset, startPosition: Double) {
        Logger.metadata.info("Loading video for specific identifier: \(identifier.identifier) from collection: \(identifier.collection)")
        
        let metadataStartTime = CFAbsoluteTimeGetCurrent()
        let metadata = try await archiveService.fetchMetadata(for: identifier.identifier)
        let metadataTime = CFAbsoluteTimeGetCurrent() - metadataStartTime
        Logger.network.info("Fetched metadata in \(String(format: "%.4f", metadataTime)) seconds")
        
        // Find MP4 file
        let mp4Files = await archiveService.findPlayableFiles(in: metadata)
        
        guard let mp4File = mp4Files.first else {
            let error = "No MP4 file found in the archive"
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
        let asset = AVURLAsset(url: videoURL)
        Logger.videoPlayback.debug("Created AVURLAsset")
        
        // Set title and description from metadata
        let title = metadata.metadata?.title ?? identifier.identifier
        let description = metadata.metadata?.description ?? "Internet Archive video"
        
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
            asset,
            randomStart
        )
    }
}

// MARK: - VideoProvider Protocol
extension SearchViewModel {
    func getNextVideo() async -> CachedVideo? {
        guard !searchResults.isEmpty else { return nil }
        
        let nextIndex = (currentIndex + 1) % searchResults.count
        guard nextIndex < searchResults.count else { return nil }
        
        let nextIdentifier = searchResults[nextIndex].identifier
        Logger.caching.info("SearchViewModel.getNextVideo: Preparing next video at index \(nextIndex)")
        
        do {
            // Convert the search result to cached video
            return try await createCachedVideo(for: nextIdentifier)
        } catch {
            Logger.caching.error("Failed to get next video: \(error.localizedDescription)")
            return nil
        }
    }
    
    func getPreviousVideo() async -> CachedVideo? {
        guard !searchResults.isEmpty else { return nil }
        
        let prevIndex = (currentIndex - 1 + searchResults.count) % searchResults.count
        guard prevIndex < searchResults.count else { return nil }
        
        let prevIdentifier = searchResults[prevIndex].identifier
        Logger.caching.info("SearchViewModel.getPreviousVideo: Preparing previous video at index \(prevIndex)")
        
        do {
            // Convert the search result to cached video
            return try await createCachedVideo(for: prevIdentifier)
        } catch {
            Logger.caching.error("Failed to get previous video: \(error.localizedDescription)")
            return nil
        }
    }
    
    func updateToNextVideo() {
        let nextIndex = (currentIndex + 1) % searchResults.count
        currentIndex = nextIndex
        currentResult = searchResults[nextIndex]
        Logger.caching.info("SearchViewModel.updateToNextVideo: Updated index to \(self.currentIndex)")
    }
    
    func updateToPreviousVideo() {
        let prevIndex = (currentIndex - 1 + searchResults.count) % searchResults.count
        currentIndex = prevIndex
        currentResult = searchResults[prevIndex]
        Logger.caching.info("SearchViewModel.updateToPreviousVideo: Updated index to \(self.currentIndex)")
    }
    
    func isAtEndOfHistory() -> Bool {
        return searchResults.isEmpty || currentIndex >= searchResults.count - 1
    }
    
    func createCachedVideoFromCurrentState() async -> CachedVideo? {
        guard let identifier = currentIdentifier, let collection = currentCollection else { return nil }
        
        let archiveIdentifier = ArchiveIdentifier(identifier: identifier, collection: collection)
        
        do {
            return try await createCachedVideo(for: archiveIdentifier)
        } catch {
            Logger.caching.error("Failed to create cached video from current state: \(error.localizedDescription)")
            return nil
        }
    }
    
    func addVideoToHistory(_ video: CachedVideo) {
        // No-op for search results
        Logger.caching.debug("SearchViewModel.addVideoToHistory: No-op for search results")
    }
    
    func ensureVideosAreCached() async {
        guard !searchResults.isEmpty else { return }
        
        Logger.caching.info("SearchViewModel.ensureVideosAreCached: Preparing videos for swipe navigation")
        
        // Use the transition manager directly since it's now a non-optional property
        Logger.caching.info("Using transition manager for direct preloading")
        
        // Preload in both directions using the transition manager (which sets the ready flags)
        async let nextTask = self.transitionManager.preloadNextVideo(provider: self)
        async let prevTask = self.transitionManager.preloadPreviousVideo(provider: self)
        
        // Wait for both preloads to complete
        _ = await (nextTask, prevTask)
        
        // Log the results
        Logger.caching.info("Direct preloading complete - nextVideoReady: \(self.transitionManager.nextVideoReady), prevVideoReady: \(self.transitionManager.prevVideoReady)")
    }
    
    private func createCachedVideo(for identifier: ArchiveIdentifier) async throws -> CachedVideo {
        // Use videoLoadingService to get video information
        let videoInfo = try await self.loadFreshRandomVideo(for: identifier)
        
        // Extract metadata for the search result
        let result = searchResults.first(where: { $0.identifier.identifier == identifier.identifier })
        let title = result?.title ?? videoInfo.title
        let description = result?.description ?? videoInfo.description
        
        let urlAsset = videoInfo.asset as! AVURLAsset
        
        // Create a CachedVideo from the loaded video information
        return CachedVideo(
            identifier: identifier.identifier,
            collection: identifier.collection,
            metadata: ArchiveMetadata(
                files: [],
                metadata: ItemMetadata(
                    identifier: identifier.identifier,
                    title: title,
                    description: description
                )
            ),
            mp4File: ArchiveFile(
                name: identifier.identifier,
                format: "h.264",
                size: "",
                length: nil
            ),
            videoURL: urlAsset.url,
            asset: urlAsset,
            playerItem: AVPlayerItem(asset: urlAsset),
            startPosition: videoInfo.startPosition,
            addedToFavoritesAt: nil
        )
    }
}

// MARK: - Favorites Support
extension SearchViewModel {
    /// Create a saved video from search result
    func createSavedVideo() async -> CachedVideo? {
        guard let identifier = currentIdentifier, let collection = currentCollection else { return nil }
        
        let archiveIdentifier = ArchiveIdentifier(identifier: identifier, collection: collection)
        
        do {
            return try await createCachedVideo(for: archiveIdentifier)
        } catch {
            Logger.caching.error("Failed to create saved video: \(error.localizedDescription)")
            return nil
        }
    }
}

