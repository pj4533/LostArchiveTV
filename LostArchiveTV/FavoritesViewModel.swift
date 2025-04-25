//
//  FavoritesViewModel.swift
//  LostArchiveTV
//
//  Created by Claude on 4/24/25.
//

import SwiftUI
import AVKit
import AVFoundation
import OSLog

@MainActor
class FavoritesViewModel: ObservableObject, VideoProvider {
    // Services
    private let archiveService = ArchiveService()
    private let playbackManager = VideoPlaybackManager()
    
    // Favorites manager
    private let favoritesManager: FavoritesManager
    
    // Published properties
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentVideo: CachedVideo?
    @Published var showMetadata = false
    @Published var videoDuration: Double = 0
    
    // Video management - needs to be public for VideoTransitionManager
    private(set) var currentIndex: Int = 0
    
    // Reference to the transition manager for preloading
    var transitionManager: VideoTransitionManager? = nil
    
    init(favoritesManager: FavoritesManager) {
        self.favoritesManager = favoritesManager
        
        // Configure audio session for proper playback
        playbackManager.setupAudioSession()
        
        // Setup duration observation
        setupDurationObserver()
    }
    
    var player: AVPlayer? {
        get { playbackManager.player }
        set {
            if let newPlayer = newValue {
                playbackManager.useExistingPlayer(newPlayer)
            } else {
                playbackManager.cleanupPlayer()
            }
        }
    }
    
    var favorites: [CachedVideo] {
        favoritesManager.favorites
    }
    
    func isFavorite(_ video: CachedVideo) -> Bool {
        favoritesManager.isFavorite(video)
    }
    
    func toggleFavorite() {
        guard let currentVideo = currentVideo else { return }
        
        favoritesManager.toggleFavorite(currentVideo)
        
        // If we're unfavoriting the current video, move to the next one
        if !favoritesManager.isFavorite(currentVideo) {
            handleVideoRemoval()
        }
        
        objectWillChange.send()
    }
    
    private func handleVideoRemoval() {
        // If we've unfavorited the current video, we need to move to another one
        let favorites = favoritesManager.favorites
        
        // If no favorites left, clear the current video
        if favorites.isEmpty {
            currentVideo = nil
            return
        }
        
        // Adjust index if needed
        if currentIndex >= favorites.count {
            currentIndex = favorites.count - 1
        }
        
        // Load the video at the adjusted index
        if currentIndex < favorites.count {
            setCurrentVideo(favorites[currentIndex])
        }
    }
    
    func playVideoAt(index: Int) {
        guard index >= 0 && index < favoritesManager.favorites.count else { return }
        
        Logger.caching.info("FavoritesViewModel.playVideoAt: Playing video at index \(index)")
        isLoading = true
        currentIndex = index
        
        // Get the selected favorite
        let video = favoritesManager.favorites[index]
        
        // Set the current video reference
        self.currentVideo = video
        
        // Create a fresh player with a new AVPlayerItem
        createAndSetupPlayer(for: video)
        
        // Important: Start a task to preload videos for swiping AFTER the player is set up
        // Use a slight delay to ensure the player is fully initialized
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            Logger.caching.info("Starting preload after player initialization")
            await ensureVideosAreCached()
        }
        
        isLoading = false
    }
    
    func setCurrentVideo(_ video: CachedVideo) {
        self.currentVideo = video
        
        // Create a fresh player with a new AVPlayerItem
        createAndSetupPlayer(for: video)
    }
    
    // Helper method to create a fresh player for a video
    private func createAndSetupPlayer(for video: CachedVideo) {
        Logger.caching.info("FavoritesViewModel: Creating player for video \(video.identifier)")
        
        // Clean up existing player first
        playbackManager.cleanupPlayer()
        
        // Create a fresh player item from the asset
        let freshPlayerItem = AVPlayerItem(asset: video.asset)
        let player = AVPlayer(playerItem: freshPlayerItem)
        let startTime = CMTime(seconds: video.startPosition, preferredTimescale: 600)
        
        // Seek to the correct position
        Task {
            Logger.caching.info("FavoritesViewModel: Setting up player and seeking to start position")
            await player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
            playbackManager.useExistingPlayer(player)
            playbackManager.play()
            Logger.caching.info("FavoritesViewModel: Player setup complete, playback started")
        }
    }
    
    // VideoProvider protocol - Get next video
    func getNextVideo() async -> CachedVideo? {
        let favorites = favoritesManager.favorites
        guard !favorites.isEmpty else { return nil }
        
        // Calculate the next index but DON'T update currentIndex yet
        // This is critical for preloading to work correctly
        let nextIndex = (currentIndex + 1) % favorites.count
        Logger.caching.info("FavoritesViewModel.getNextVideo: Returning video at index \(nextIndex)")
        
        // Return the video without updating currentIndex
        return favorites[nextIndex]
    }
    
    // VideoProvider protocol - Get previous video
    func getPreviousVideo() async -> CachedVideo? {
        let favorites = favoritesManager.favorites
        guard !favorites.isEmpty else { return nil }
        
        // Calculate the previous index but DON'T update currentIndex yet
        let previousIndex = (currentIndex - 1 + favorites.count) % favorites.count
        Logger.caching.info("FavoritesViewModel.getPreviousVideo: Returning video at index \(previousIndex)")
        
        // Return the video without updating currentIndex
        return favorites[previousIndex]
    }
    
    // Methods for VideoTransitionManager to use when transitioning
    func updateToNextVideo() {
        let favorites = favoritesManager.favorites
        guard !favorites.isEmpty else { return }
        
        // Update the index when actually moving to the next video
        let nextIndex = (currentIndex + 1) % favorites.count
        currentIndex = nextIndex
        Logger.caching.info("FavoritesViewModel.updateToNextVideo: Updated index to \(self.currentIndex)")
        
        // DO NOT call setCurrentVideo here - that will be handled by the transition manager
        // This method only updates the index, not the UI
    }
    
    func updateToPreviousVideo() {
        let favorites = favoritesManager.favorites
        guard !favorites.isEmpty else { return }
        
        // Update the index when actually moving to the previous video
        let previousIndex = (currentIndex - 1 + favorites.count) % favorites.count
        currentIndex = previousIndex
        Logger.caching.info("FavoritesViewModel.updateToPreviousVideo: Updated index to \(self.currentIndex)")
        
        // DO NOT call setCurrentVideo here - that will be handled by the transition manager
        // This method only updates the index, not the UI
    }
    
    // Public methods for direct navigation (not during swipe)
    func goToNextVideo() {
        let favorites = favoritesManager.favorites
        guard !favorites.isEmpty else { return }
        
        updateToNextVideo()
        setCurrentVideo(favorites[currentIndex])
    }
    
    func goToPreviousVideo() {
        let favorites = favoritesManager.favorites
        guard !favorites.isEmpty else { return }
        
        updateToPreviousVideo()
        setCurrentVideo(favorites[currentIndex])
    }
    
    func pausePlayback() {
        playbackManager.pause()
    }
    
    func resumePlayback() {
        playbackManager.play()
    }
    
    func restartVideo() {
        playbackManager.seekToBeginning()
    }
    
    func togglePlayPause() {
        if playbackManager.isPlaying {
            playbackManager.pause()
        } else {
            playbackManager.play()
        }
    }
    
    var isPlaying: Bool {
        playbackManager.isPlaying
    }
    
    func toggleMetadata() {
        showMetadata.toggle()
    }
    
    func openSafari() {
        guard let identifier = currentVideo?.identifier else { return }
        let urlString = "https://archive.org/details/\(identifier)"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - VideoProvider Protocol Implementation
    
    var currentIdentifier: String? {
        get { currentVideo?.identifier }
        set {
            if let newValue = newValue, let index = favorites.firstIndex(where: { $0.identifier == newValue }) {
                currentVideo = favorites[index]
            }
        }
    }
    
    var currentTitle: String? {
        get { currentVideo?.title }
        set { /* Title is determined by currentIdentifier or currentVideo */ }
    }
    
    var currentCollection: String? {
        get { currentVideo?.collection }
        set { /* Collection is determined by currentIdentifier or currentVideo */ }
    }
    
    var currentDescription: String? {
        get { currentVideo?.description }
        set { /* Description is determined by currentIdentifier or currentVideo */ }
    }
    
    func isAtEndOfHistory() -> Bool {
        currentIndex >= favoritesManager.favorites.count - 1 || favoritesManager.favorites.isEmpty
    }
    
    func createCachedVideoFromCurrentState() async -> CachedVideo? {
        return currentVideo
    }
    
    func addVideoToHistory(_ video: CachedVideo) {
        // No-op for favorites - we don't maintain a separate history
    }
    
    func ensureVideosAreCached() async {
        Logger.caching.info("FavoritesViewModel.ensureVideosAreCached: Preparing videos for swipe navigation")
        
        // If we have a reference to the transition manager, use it directly
        if let transitionManager = transitionManager {
            Logger.caching.info("Using transition manager for direct preloading")
            
            // Preload in both directions using the transition manager (which sets the ready flags)
            async let nextTask = transitionManager.preloadNextVideo(provider: self)
            async let prevTask = transitionManager.preloadPreviousVideo(provider: self)
            
            // Wait for both preloads to complete
            _ = await (nextTask, prevTask)
            
            // Log the results
            Logger.caching.info("Direct preloading complete - nextVideoReady: \(transitionManager.nextVideoReady), prevVideoReady: \(transitionManager.prevVideoReady)")
        } else {
            Logger.caching.error("⚠️ No transition manager available for preloading")
            
            // Fallback: just get the videos without setting up players
            async let nextTask = Task {
                await getNextVideo()
            }
            
            async let prevTask = Task {
                await getPreviousVideo()
            }
            
            // Wait for both tasks to complete
            _ = await [nextTask.value, prevTask.value]
        }
    }
    
    // MARK: - Duration Observation
    
    private func setupDurationObserver() {
        Task {
            for await _ in playbackManager.$videoDuration.values {
                self.videoDuration = playbackManager.videoDuration
            }
        }
    }
}