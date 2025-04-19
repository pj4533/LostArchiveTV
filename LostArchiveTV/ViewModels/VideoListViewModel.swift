import Foundation
import SwiftUI
import OSLog

@MainActor
class VideoListViewModel: ObservableObject {
    @Published var videos: [ArchiveVideo] = []
    @Published var isLoading = false
    @Published var error: String?
    
    // Search parameters
    private var currentQuery = "funk"
    private var currentPage = 1
    private var hasMorePages = true
    
    // Fetch initial videos
    func loadInitialVideos() async {
        Logger.ui.info("Loading initial videos with query: \(self.currentQuery)")
        videos = []
        currentPage = 1
        await searchVideos(query: currentQuery)
    }
    
    // Load more videos for infinite scrolling
    func loadMoreVideosIfNeeded() async {
        guard !isLoading, hasMorePages else {
            Logger.ui.debug("Skipping load more: isLoading=\(self.isLoading), hasMorePages=\(self.hasMorePages)")
            return
        }
        Logger.ui.info("Loading more videos (page \(self.currentPage + 1))")
        currentPage += 1
        await searchVideos(query: currentQuery)
    }
    
    // Search videos with a specific query
    private func searchVideos(query: String) async {
        guard !isLoading else {
            Logger.ui.debug("Search already in progress, skipping request")
            return
        }
        
        Logger.ui.debug("Starting search with query: '\(query)', page: \(self.currentPage)")
        isLoading = true
        error = nil
        
        do {
            let newVideos = try await ArchiveService.shared.searchVideos(
                query: query, 
                page: currentPage
            )
            
            // Append new videos to the existing list
            videos.append(contentsOf: newVideos)
            Logger.ui.info("Added \(newVideos.count) videos to the list (total: \(self.videos.count))")
            
            // Check if we've reached the end
            hasMorePages = !newVideos.isEmpty
            if !hasMorePages {
                Logger.ui.notice("Reached the end of search results for query: '\(query)'")
            }
        } catch {
            Logger.ui.error("Failed to load videos: \(error.localizedDescription)")
            self.error = "Failed to load videos: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}