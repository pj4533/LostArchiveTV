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
class FavoritesViewModel: BaseVideoViewModel, VideoProvider {
    // Services
    private let archiveService = ArchiveService()
    
    // Favorites manager
    private let favoritesManager: FavoritesManager
    
    // Additional published properties
    @Published var currentVideo: CachedVideo?
    @Published var showMetadata = false
    
    // Video management - needs to be public for VideoTransitionManager
    private(set) var currentIndex: Int = 0
    
    // Reference to the transition manager for preloading
    var transitionManager: VideoTransitionManager? = nil
    
    override init() {
        // This empty init is needed to satisfy the compiler
        // We'll use the designated init instead
        fatalError("Use init(favoritesManager:) instead")
    }
    
    init(favoritesManager: FavoritesManager) {
        self.favoritesManager = favoritesManager
        
        // Call base class init
        super.init()
        
        // Setup property synchronization
        setupVideoPropertySynchronization()
    }
    
    /// Sets up synchronization between currentVideo and base class properties
    private func setupVideoPropertySynchronization() {
        // When currentVideo changes, update all the base class properties
        Task {
            // Use delayed update to allow properties to be properly initialized
            try? await Task.sleep(for: .seconds(0.1))
            
            // Set initial values from currentVideo (if available)
            updateBasePropertiesFromCurrentVideo()
        }
    }
    
    /// Updates base class properties from currentVideo
    private func updateBasePropertiesFromCurrentVideo() {
        if let video = currentVideo {
            currentIdentifier = video.identifier
            currentTitle = video.title
            currentCollection = video.collection
            currentDescription = video.description
        }
    }
    
    // MARK: - VideoControlProvider Protocol Overrides
    
    override var isFavorite: Bool {
        guard let currentVideo = currentVideo else { return false }
        return favoritesManager.isFavorite(currentVideo)
    }
    
    override func toggleFavorite() {
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
}

// MARK: - Public Interface
extension FavoritesViewModel {
    var favorites: [CachedVideo] {
        favoritesManager.favorites
    }
    
    func isFavorite(_ video: CachedVideo) -> Bool {
        favoritesManager.isFavorite(video)
    }
}

// MARK: - Video Playback
extension FavoritesViewModel {
    func playVideoAt(index: Int) {
        guard index >= 0 && index < favoritesManager.favorites.count else { return }
        
        Logger.caching.info("FavoritesViewModel.playVideoAt: Playing video at index \(index)")
        isLoading = true
        currentIndex = index
        
        // Get the selected favorite
        let video = favoritesManager.favorites[index]
        
        // Set the current video reference
        self.currentVideo = video
        
        // Update base class properties
        updateBasePropertiesFromCurrentVideo()
        
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
        
        // Update base class properties
        updateBasePropertiesFromCurrentVideo()
        
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
}

// MARK: - UI Interactions
extension FavoritesViewModel {
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
}
    
// MARK: - Video Navigation
extension FavoritesViewModel {
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
    
    func isAtEndOfHistory() -> Bool {
        currentIndex >= favoritesManager.favorites.count - 1 || favoritesManager.favorites.isEmpty
    }
    
    func createCachedVideoFromCurrentState() async -> CachedVideo? {
        return currentVideo
    }
    
    func addVideoToHistory(_ video: CachedVideo) {
        // No-op for favorites - we don't maintain a separate history
    }
}

// MARK: - Cache Management
extension FavoritesViewModel {
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
}