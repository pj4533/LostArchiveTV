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
    
    // Video management
    private var currentIndex: Int = 0
    
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
        
        isLoading = true
        currentIndex = index
        setCurrentVideo(favoritesManager.favorites[index])
        isLoading = false
    }
    
    func setCurrentVideo(_ video: CachedVideo) {
        self.currentVideo = video
        
        // Create a player with the asset
        let player = AVPlayer(playerItem: video.playerItem)
        let startTime = CMTime(seconds: video.startPosition, preferredTimescale: 600)
        
        // Seek to the correct position
        Task {
            await player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
            playbackManager.useExistingPlayer(player)
            playbackManager.play()
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
    
    // Original methods that use the protocol methods internally
    func goToNextVideo() {
        let favorites = favoritesManager.favorites
        guard !favorites.isEmpty else { return }
        
        // Update the index when actually moving to the next video
        let nextIndex = (currentIndex + 1) % favorites.count
        currentIndex = nextIndex
        Logger.caching.info("FavoritesViewModel.goToNextVideo: Moving to index \(self.currentIndex)")
        
        setCurrentVideo(favorites[nextIndex])
    }
    
    func goToPreviousVideo() {
        let favorites = favoritesManager.favorites
        guard !favorites.isEmpty else { return }
        
        // Update the index when actually moving to the previous video
        let previousIndex = (currentIndex - 1 + favorites.count) % favorites.count
        currentIndex = previousIndex
        Logger.caching.info("FavoritesViewModel.goToPreviousVideo: Moving to index \(self.currentIndex)")
        
        setCurrentVideo(favorites[previousIndex])
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
        set { /* No-op - handled via currentVideo */ }
    }
    
    var currentTitle: String? {
        get { currentVideo?.title }
        set { /* No-op - handled via currentVideo */ }
    }
    
    var currentCollection: String? {
        get { currentVideo?.collection }
        set { /* No-op - handled via currentVideo */ }
    }
    
    var currentDescription: String? {
        get { currentVideo?.description }
        set { /* No-op - handled via currentVideo */ }
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
        // No additional preloading needed for favorites - they're already loaded
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