import Foundation
import SwiftUI
import OSLog

@MainActor
class FavoritesFeedViewModel: BaseFeedViewModel<FavoritesFeedItem> {
    private let favoritesManager: FavoritesManager
    @Published var showPlayer = false
    @Published var selectedIndex: Int?
    
    // References to the video player components
    let favoritesViewModel: FavoritesViewModel
    
    init(favoritesManager: FavoritesManager, favoritesViewModel: FavoritesViewModel) {
        self.favoritesManager = favoritesManager
        self.favoritesViewModel = favoritesViewModel
        super.init()
        
        // Set up bidirectional reference for pagination support
        favoritesViewModel.linkedFeedViewModel = self
    }
    
    override func loadMoreItems(reset: Bool = false) async {
        if isLoading { return }
        isLoading = true
        
        // Get paginated favorites
        let favorites = favoritesManager.getFavorites(
            page: reset ? 0 : currentPage,
            pageSize: pageSize
        )
        
        // Convert to feed items
        let newItems = favorites.map { FavoritesFeedItem(cachedVideo: $0) }
        
        // Update the items array
        if reset {
            items = newItems
            currentPage = 1 // Set to 1 since we've loaded the first page
        } else {
            items.append(contentsOf: newItems)
            currentPage += 1
        }
        
        // Update hasMoreItems flag
        hasMoreItems = favoritesManager.hasMoreFavorites(currentCount: items.count)
        isLoading = false
        
        Logger.metadata.debug("Loaded page \(self.currentPage-1) of favorites with \(newItems.count) items. Has more: \(self.hasMoreItems)")
    }
    
    override func selectItem(_ item: FavoritesFeedItem) {
        // Find the index of the selected item in the favorites list
        if let index = favoritesManager.favorites.firstIndex(where: { $0.id == item.id }) {
            selectedIndex = index
            
            // Play the video using the existing favorites view model
            favoritesViewModel.playVideoAt(index: index)
            
            // Ensure the transition manager is ready for preloading
            // This is particularly important if the manager wasn't set by the SwipeablePlayerView yet
            if favoritesViewModel.transitionManager == nil {
                favoritesViewModel.transitionManager = VideoTransitionManager()
            }
            
            // Show the player immediately for better user experience
            self.showPlayer = true
            
            // Note: ensureVideosAreCached() will be called by the player
            // after the video starts playing, avoiding race conditions
        }
    }
}