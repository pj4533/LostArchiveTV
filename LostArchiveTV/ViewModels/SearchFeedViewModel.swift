import Foundation
import SwiftUI
import OSLog

@MainActor
class SearchFeedViewModel: BaseFeedViewModel<SearchFeedItem> {
    private let searchManager: SearchManager
    
    // References to the existing search components
    @ObservedObject var searchViewModel: SearchViewModel
    @Published var searchQuery = ""
    @Published var searchFilter = SearchFilter()
    @Published var showingPlayer = false
    
    // Task management
    private var searchTask: Task<Void, Never>?
    
    init(searchManager: SearchManager, searchViewModel: SearchViewModel) {
        self.searchManager = searchManager
        self.searchViewModel = searchViewModel
        super.init()
    }
    
    func search() async {
        guard !searchQuery.isEmpty else {
            items = []
            errorMessage = nil
            hasMoreItems = false
            return
        }
        
        // Cancel any pending search task
        searchTask?.cancel()
        
        // Create a new search task
        searchTask = Task {
            isLoading = true
            errorMessage = nil
            
            do {
                guard !Task.isCancelled else { return }
                
                Logger.caching.info("Performing search for query: \(self.searchQuery)")
                
                // Reset pagination
                currentPage = 0
                
                // Load first page
                let results = try await searchManager.search(
                    query: self.searchQuery,
                    filter: searchFilter,
                    page: currentPage,
                    pageSize: pageSize
                )
                
                // Check if task was cancelled during network operation
                guard !Task.isCancelled else { return }
                
                // Convert to feed items
                let newItems = results.map { SearchFeedItem(searchResult: $0) }
                
                // Update items
                items = newItems
                
                // Store the full results in the search view model for later use
                searchViewModel.searchResults = results
                
                // Update pagination state
                currentPage = 1  // We've loaded page 0, so next will be page 1
                hasMoreItems = results.count == pageSize  // If we got a full page, there might be more
                
                isLoading = false
                
            } catch {
                // Handle cancellation
                if Task.isCancelled {
                    Logger.network.info("Search task was cancelled")
                    isLoading = false
                    return
                }
                
                // Handle error
                errorMessage = "Search failed: \(error.localizedDescription)"
                Logger.network.error("Search failed: \(error.localizedDescription)")
                isLoading = false
            }
        }
    }
    
    override func loadMoreItems(reset: Bool = false) async {
        // If we're doing a new search, use the search method instead
        if reset {
            await search()
            return
        }
        
        // If already loading or no more items, return
        if isLoading || !hasMoreItems { return }
        
        isLoading = true
        
        do {
            // Load the next page
            let results = try await searchManager.search(
                query: searchQuery,
                filter: searchFilter,
                page: currentPage,
                pageSize: pageSize
            )
            
            // Convert to feed items
            let newItems = results.map { SearchFeedItem(searchResult: $0) }
            
            // Add to existing items
            items.append(contentsOf: newItems)
            
            // Add to the search view model's results too
            searchViewModel.searchResults.append(contentsOf: results)
            
            // Update pagination state
            currentPage += 1
            hasMoreItems = results.count == pageSize
            
            Logger.caching.info("Loaded page \(self.currentPage-1) with \(newItems.count) items. Has more: \(self.hasMoreItems)")
            
        } catch {
            errorMessage = "Failed to load more results: \(error.localizedDescription)"
            Logger.caching.error("Failed to load more results: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    override func refreshItems() async {
        await search()
    }
    
    override func selectItem(_ item: SearchFeedItem) {
        // Find the index of the selected item in the search results
        if let index = searchViewModel.searchResults.firstIndex(where: { $0.identifier.identifier == item.id }) {
            // Play the video using the existing search view model
            searchViewModel.playVideoAt(index: index)
            self.showingPlayer = true
        }
    }
}