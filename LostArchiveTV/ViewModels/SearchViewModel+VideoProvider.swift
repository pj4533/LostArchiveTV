//
//  SearchViewModel+VideoProvider.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import Foundation
import AVKit
import AVFoundation
import OSLog
import SwiftUI

// MARK: - VideoProvider Protocol
extension SearchViewModel {
    // Get next video by moving the index position - modifies state
    func getNextVideo() async -> CachedVideo? {
        guard !searchResults.isEmpty else { return nil }
        
        let nextIndex = (currentIndex + 1) % searchResults.count
        guard nextIndex < searchResults.count else { return nil }
        
        // Update the currentIndex - this is the key difference from peekNextVideo
        currentIndex = nextIndex
        
        let nextIdentifier = searchResults[nextIndex].identifier
        Logger.caching.info("💫 SEARCH: getNextVideo - Moving to index \(nextIndex)")
        
        do {
            // Convert the search result to cached video
            return try await createCachedVideo(for: nextIdentifier)
        } catch {
            Logger.caching.error("Failed to get next video: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Get previous video by moving the index position - modifies state
    func getPreviousVideo() async -> CachedVideo? {
        guard !searchResults.isEmpty else { return nil }
        
        let prevIndex = (currentIndex - 1 + searchResults.count) % searchResults.count
        guard prevIndex < searchResults.count else { return nil }
        
        // Update the currentIndex - this is the key difference from peekPreviousVideo
        currentIndex = prevIndex
        
        let prevIdentifier = searchResults[prevIndex].identifier
        Logger.caching.info("💫 SEARCH: getPreviousVideo - Moving to index \(prevIndex)")
        
        do {
            // Convert the search result to cached video
            return try await createCachedVideo(for: prevIdentifier)
        } catch {
            Logger.caching.error("Failed to get previous video: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Peek at next video without changing the current index - for preloading
    func peekNextVideo() async -> CachedVideo? {
        guard !searchResults.isEmpty else { return nil }
        
        let nextIndex = (currentIndex + 1) % searchResults.count
        guard nextIndex < searchResults.count else { return nil }
        
        let nextIdentifier = searchResults[nextIndex].identifier
        Logger.caching.info("👁️ SEARCH: peekNextVideo - Peeking at index \(nextIndex) (current: \(self.currentIndex))")
        
        do {
            // Convert the search result to cached video
            return try await createCachedVideo(for: nextIdentifier)
        } catch {
            Logger.caching.error("Failed to peek at next video: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Peek at previous video without changing the current index - for preloading
    func peekPreviousVideo() async -> CachedVideo? {
        guard !searchResults.isEmpty else { return nil }
        
        let prevIndex = (currentIndex - 1 + searchResults.count) % searchResults.count
        guard prevIndex < searchResults.count else { return nil }
        
        let prevIdentifier = searchResults[prevIndex].identifier
        Logger.caching.info("👁️ SEARCH: peekPreviousVideo - Peeking at index \(prevIndex) (current: \(self.currentIndex))")
        
        do {
            // Convert the search result to cached video
            return try await createCachedVideo(for: prevIdentifier)
        } catch {
            Logger.caching.error("Failed to peek at previous video: \(error.localizedDescription)")
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
        let isAtEnd = searchResults.isEmpty || currentIndex >= searchResults.count - 1
        
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
        if currentIndex >= searchResults.count - 3 { // Start loading when 3 items from the end
            Logger.caching.info("SearchViewModel: Need to load more search results")
            
            // Use the linked feed view model to load more items
            if let feedViewModel = linkedFeedViewModel, 
               feedViewModel.hasMoreItems && !feedViewModel.isLoading {
                Logger.caching.info("SearchViewModel: Loading more items via linkedFeedViewModel")
                await feedViewModel.loadMoreItems()
                return true
            }
        }
        
        return false
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
    
    // Keep the function name but we need to split this into smaller parts first
    // before we can reintegrate it
    
    // Helper method to get identifiers for caching
    private func getSearchIdentifiersForCaching() -> [ArchiveIdentifier] {
        var identifiers: [ArchiveIdentifier] = []
        
        // Add current result and next few results
        let startIndex = currentIndex
        let endIndex = min(startIndex + 3, searchResults.count)
        
        for i in startIndex..<endIndex {
            identifiers.append(searchResults[i].identifier)
        }
        
        return identifiers
    }
    
    internal func createCachedVideo(for identifier: ArchiveIdentifier) async throws -> CachedVideo {
        // Use videoLoadingService to get video information
        let videoInfo = try await self.loadFreshRandomVideo(for: identifier)
        
        // Extract metadata for the search result
        let result = searchResults.first(where: { $0.identifier.identifier == identifier.identifier })
        let title = result?.title ?? videoInfo.title
        let description = result?.description ?? videoInfo.description
        
        let urlAsset = videoInfo.asset as! AVURLAsset
        
        // Use cached file count or fetch if not in cache
        let fileCount = await fetchFileCount(for: identifier.identifier) ?? 1

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
                name: videoInfo.filename,
                format: "h.264",
                size: "",
                length: nil
            ),
            videoURL: urlAsset.url,
            asset: urlAsset,
            startPosition: videoInfo.startPosition,
            addedToFavoritesAt: nil,
            totalFiles: fileCount
        )
    }
}