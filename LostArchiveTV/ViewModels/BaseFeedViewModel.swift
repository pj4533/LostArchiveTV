import Foundation
import SwiftUI
import OSLog

@MainActor
class BaseFeedViewModel<Item: FeedItem>: ObservableObject {
    @Published var items: [Item] = []
    @Published var isLoading = false
    @Published var hasMoreItems = true
    @Published var errorMessage: String? = nil
    
    var currentPage = 0
    var pageSize = 20
    
    func loadInitialItems() async {
        currentPage = 0
        await loadMoreItems(reset: true)
    }
    
    func loadMoreItems(reset: Bool = false) async {
        // To be overridden by subclasses
        fatalError("Subclasses must override loadMoreItems")
    }
    
    func refreshItems() async {
        await loadInitialItems()
    }
    
    func selectItem(_ item: Item) {
        // To be overridden by subclasses
        fatalError("Subclasses must override selectItem")
    }
}