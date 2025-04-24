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
class VideoPlayerViewModel: ObservableObject, VideoProvider {
    // Services
    let archiveService = ArchiveService()
    let cacheManager = VideoCacheManager()
    private let preloadService = PreloadService()
    private let playbackManager = VideoPlaybackManager()
    private lazy var videoLoadingService = VideoLoadingService(
        archiveService: archiveService,
        cacheManager: cacheManager
    )
    
    // Favorites manager
    let favoritesManager: FavoritesManager
    
    // Published properties - these are the public interface of our ViewModel
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentIdentifier: String?
    @Published var currentCollection: String?
    @Published var currentTitle: String?
    @Published var currentDescription: String?
    
    // New properties for tracking app initialization
    @Published var isInitializing = true
    
    // Cache monitoring
    private var cacheMonitorTask: Task<Void, Never>?
    
    // Archive.org video identifiers
    private var identifiers: [ArchiveIdentifier] = []
    
    // Video history tracking - simple array with current index
    private var videoHistory: [CachedVideo] = []
    private var currentHistoryIndex: Int = -1
    
    // Current cached video reference for favorites
    private var _currentCachedVideo: CachedVideo?
    
    // MARK: - Initialization and Cleanup
    init(favoritesManager: FavoritesManager) {
        self.favoritesManager = favoritesManager
        
        // Configure audio session for proper playback on all devices
        playbackManager.setupAudioSession()
        
        // Set initial state
        isInitializing = true
        
        // Setup duration observation
        setupDurationObserver()
        
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
    
    @Published var videoDuration: Double = 0
    
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
    
    func restartVideo() {
        Logger.videoPlayback.info("Restarting video from the beginning")
        playbackManager.seekToBeginning()
    }
    
    // MARK: - Video Loading
    
    private func loadIdentifiers() async {
        do {
            // Use user preferences when loading identifiers
            identifiers = try await videoLoadingService.loadIdentifiersWithUserPreferences()
            Logger.metadata.info("Successfully loaded \(self.identifiers.count) identifiers with user preferences")
        } catch {
            Logger.metadata.error("Failed to load identifiers: \(error.localizedDescription)")
            self.errorMessage = "Failed to load video identifiers: \(error.localizedDescription)"
            isInitializing = false
        }
    }
    
    // Public method to reload identifiers when collection preferences change
    func reloadIdentifiers() async {
        Logger.metadata.info("Reloading identifiers due to collection preference changes")
        
        // Clear the cache to ensure we don't show videos from collections that might now be disabled
        await cacheManager.clearCache()
        
        // Clear existing identifiers 
        identifiers = []
        
        // Load identifiers with new preferences
        await loadIdentifiers()
        
        // Start preloading new videos from the updated collection list
        Task {
            await ensureVideosAreCached()
        }
        
        // Note: We don't automatically load a new video or change the current one
        // The user will see the effect of their changes when they swipe to the next video
        Logger.metadata.info("Collection settings updated, changes will apply to next videos")
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
            
            // Setup observation of playback manager's duration
            setupDurationObserver()
            
            // Always start playback of the video
            playbackManager.play()
            
            // Monitor buffer status
            if let playerItem = playbackManager.player?.currentItem {
                Task {
                    await playbackManager.monitorBufferStatus(for: playerItem)
                }
            }
            
            // Save the first loaded video to history
            if let currentVideo = await createCachedVideoFromCurrentState() {
                addVideoToHistory(currentVideo)
                updateCurrentCachedVideo(currentVideo)
                Logger.caching.info("Added initial video to history")
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
    
    // MARK: - History Management
    
    // Add a video to history (at the end)
    func addVideoToHistory(_ video: CachedVideo) {
        // If we're not at the end of history, truncate forward history
        if currentHistoryIndex < self.videoHistory.count - 1 {
            self.videoHistory = Array(self.videoHistory[0...self.currentHistoryIndex])
        }
        
        // Check if we're about to add a duplicate of the last video
        if let lastVideo = self.videoHistory.last, lastVideo.identifier == video.identifier {
            Logger.caching.info("Skipping duplicate video in history: \(video.identifier)")
            return
        }
        
        // Add new video to history
        self.videoHistory.append(video)
        self.currentHistoryIndex = self.videoHistory.count - 1
        
        Logger.caching.info("Added video to history: \(video.identifier), history size: \(self.videoHistory.count), index: \(self.currentHistoryIndex)")
    }
    
    // Get previous video from history
    func getPreviousVideo() async -> CachedVideo? {
        guard currentHistoryIndex > 0, !videoHistory.isEmpty else {
            Logger.caching.info("No previous video in history")
            return nil
        }
        
        self.currentHistoryIndex -= 1
        let video = self.videoHistory[self.currentHistoryIndex]
        Logger.caching.info("Moving back in history to index \(self.currentHistoryIndex): \(video.identifier)")
        return video
    }
    
    // Get next video from history (or nil if we need a new one)
    func getNextVideo() async -> CachedVideo? {
        // If we're at the end of history, return nil (caller should load a new video)
        guard currentHistoryIndex < videoHistory.count - 1, !videoHistory.isEmpty else {
            Logger.caching.info("At end of history, need to load a new video")
            return nil
        }
        
        // Move forward in history
        self.currentHistoryIndex += 1
        let video = self.videoHistory[self.currentHistoryIndex]
        Logger.caching.info("Moving forward in history to index \(self.currentHistoryIndex): \(video.identifier)")
        return video
    }
    
    // Check if we're at the end of history
    func isAtEndOfHistory() -> Bool {
        return currentHistoryIndex >= videoHistory.count - 1
    }
    
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
            startPosition: currentTime
        )
        
        return cachedVideo
    }
    
    // MARK: - Caching and Video Trimming
    
    func ensureVideosAreCached() async {
        await preloadService.ensureVideosAreCached(
            cacheManager: cacheManager,
            archiveService: archiveService,
            identifiers: identifiers
        )
    }
    
    // MARK: - Duration Observation
    
    private func setupDurationObserver() {
        // Create an observation of the playbackManager's videoDuration property
        Task {
            for await _ in playbackManager.$videoDuration.values {
                // Update our own published property when playbackManager's duration changes
                self.videoDuration = playbackManager.videoDuration
            }
        }
    }
    
    // MARK: - Favorites Functionality
    
    var currentCachedVideo: CachedVideo? {
        _currentCachedVideo
    }
    
    // Method to update the current cached video reference
    func updateCurrentCachedVideo(_ video: CachedVideo?) {
        _currentCachedVideo = video
        objectWillChange.send()
    }
    
    var isFavorite: Bool {
        if let currentVideo = _currentCachedVideo, currentVideo.identifier == currentIdentifier {
            return favoritesManager.isFavorite(currentVideo)
        } else if let identifier = currentIdentifier {
            return favoritesManager.isFavoriteIdentifier(identifier)
        }
        return false
    }
    
    func toggleFavorite() {
        guard let currentVideo = _currentCachedVideo else { return }
        
        Logger.metadata.info("Toggling favorite status for video: \(currentVideo.identifier)")
        favoritesManager.toggleFavorite(currentVideo)
        objectWillChange.send()
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