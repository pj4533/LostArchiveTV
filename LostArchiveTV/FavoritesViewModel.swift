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
class FavoritesViewModel: ObservableObject {
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
    
    func goToNextVideo() {
        let favorites = favoritesManager.favorites
        guard !favorites.isEmpty else { return }
        
        let nextIndex = (currentIndex + 1) % favorites.count
        currentIndex = nextIndex
        setCurrentVideo(favorites[nextIndex])
    }
    
    func goToPreviousVideo() {
        let favorites = favoritesManager.favorites
        guard !favorites.isEmpty else { return }
        
        let previousIndex = (currentIndex - 1 + favorites.count) % favorites.count
        currentIndex = previousIndex
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
    
    // MARK: - Duration Observation
    
    private func setupDurationObserver() {
        Task {
            for await _ in playbackManager.$videoDuration.values {
                self.videoDuration = playbackManager.videoDuration
            }
        }
    }
}