//
//  SearchViewModel+Search.swift
//  LostArchiveTV
//
//  Created by Claude on 2025-06-30.
//

import Foundation
import OSLog

extension SearchViewModel {
    // MARK: - Search Operations
    
    func search() async {
        guard !self.searchQuery.isEmpty else {
            searchResults = []
            return
        }
        
        // Clear file count cache when starting a new search
        _fileCountCache.removeAll()
        fileCountCacheVersion += 1  // Trigger UI update
        Logger.caching.info("Cleared file count cache for new search")
        
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
}