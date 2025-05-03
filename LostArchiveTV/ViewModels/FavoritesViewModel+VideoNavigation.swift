//
//  FavoritesViewModel+VideoNavigation.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import SwiftUI
import AVKit
import AVFoundation
import OSLog

// MARK: - Video Navigation
extension FavoritesViewModel {
    // VideoProvider protocol - Get next video (changes index when called)
    func getNextVideo() async -> CachedVideo? {
        let favorites = favoritesManager.favorites
        guard !favorites.isEmpty else { return nil }
        
        // Calculate the next index and update currentIndex
        let nextIndex = (currentIndex + 1) % favorites.count
        currentIndex = nextIndex
        Logger.caching.info("💫 FAVORITES: getNextVideo - Moving to index \(nextIndex)")
        
        return favorites[nextIndex]
    }
    
    // VideoProvider protocol - Get previous video (changes index when called)
    func getPreviousVideo() async -> CachedVideo? {
        let favorites = favoritesManager.favorites
        guard !favorites.isEmpty else { return nil }
        
        // Calculate the previous index and update currentIndex
        let previousIndex = (currentIndex - 1 + favorites.count) % favorites.count
        currentIndex = previousIndex
        Logger.caching.info("💫 FAVORITES: getPreviousVideo - Moving to index \(previousIndex)")
        
        return favorites[previousIndex]
    }
    
    // VideoProvider protocol - Peek at next video without changing index
    func peekNextVideo() async -> CachedVideo? {
        let favorites = favoritesManager.favorites
        guard !favorites.isEmpty else { return nil }
        
        // Calculate the next index but DON'T update currentIndex
        let nextIndex = (currentIndex + 1) % favorites.count
        Logger.caching.info("👁️ FAVORITES: peekNextVideo - Peeking at index \(nextIndex) (current: \(self.currentIndex))")
        
        return favorites[nextIndex]
    }
    
    // VideoProvider protocol - Peek at previous video without changing index
    func peekPreviousVideo() async -> CachedVideo? {
        let favorites = favoritesManager.favorites
        guard !favorites.isEmpty else { return nil }
        
        // Calculate the previous index but DON'T update currentIndex
        let previousIndex = (currentIndex - 1 + favorites.count) % favorites.count
        Logger.caching.info("👁️ FAVORITES: peekPreviousVideo - Peeking at index \(previousIndex) (current: \(self.currentIndex))")
        
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
        let isAtEnd = currentIndex >= favoritesManager.favorites.count - 1 || favoritesManager.favorites.isEmpty
        
        // If we're at the end, trigger loading more items
        if isAtEnd {
            Task {
                _ = await loadMoreItemsIfNeeded()
            }
        }
        
        return isAtEnd
    }
    
    func loadMoreItemsIfNeeded() async -> Bool {
        // If we're at the end, try to load more items
        if currentIndex >= favoritesManager.favorites.count - 3 { // Start loading when 3 items from the end
            Logger.caching.info("FavoritesViewModel: Need to load more favorite items")
            
            // Use linked feed view model if available, but since favorites are all
            // locally stored, we typically don't need to load more from a server
            if let feedViewModel = linkedFeedViewModel, 
               feedViewModel.hasMoreItems && !feedViewModel.isLoading {
                Logger.caching.info("FavoritesViewModel: Loading more items via linkedFeedViewModel")
                await feedViewModel.loadMoreItems()
                return true
            }
        }
        
        return false
    }
    
    func createCachedVideoFromCurrentState() async -> CachedVideo? {
        return currentVideo
    }
    
    func addVideoToHistory(_ video: CachedVideo) {
        // No-op for favorites - we don't maintain a separate history
    }
}