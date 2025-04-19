import Foundation
import SwiftUI

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
        videos = []
        currentPage = 1
        await searchVideos(query: currentQuery)
    }
    
    // Load more videos for infinite scrolling
    func loadMoreVideosIfNeeded() async {
        guard !isLoading, hasMorePages else { return }
        currentPage += 1
        await searchVideos(query: currentQuery)
    }
    
    // Search videos with a specific query
    private func searchVideos(query: String) async {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        do {
            let newVideos = try await ArchiveService.shared.searchVideos(
                query: query, 
                page: currentPage
            )
            
            // Append new videos to the existing list
            videos.append(contentsOf: newVideos)
            
            // Check if we've reached the end
            hasMorePages = !newVideos.isEmpty
        } catch {
            self.error = "Failed to load videos: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}