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
    internal let favoritesManager: FavoritesManager
    
    // Additional published properties
    @Published var currentVideo: CachedVideo?
    @Published var showMetadata = false
    
    // Video management - needs to be public for VideoTransitionManager
    // Changed to internal with setter for extensions to access
    internal var currentIndex: Int = 0
    
    // Reference to the transition manager for preloading
    var transitionManager: VideoTransitionManager? = nil
    
    // Reference to feed view model for pagination support
    weak var linkedFeedViewModel: FavoritesFeedViewModel?
    
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
    internal func updateBasePropertiesFromCurrentVideo() {
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