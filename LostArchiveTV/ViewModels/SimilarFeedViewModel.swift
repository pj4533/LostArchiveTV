import Foundation
import SwiftUI
import OSLog

@MainActor
class SimilarFeedViewModel: BaseFeedViewModel<SimilarFeedItem> {
    private let pineconeService: PineconeService
    private let referenceIdentifier: String
    @Published var selectedItem: SimilarFeedItem?
    
    init(referenceIdentifier: String, pineconeService: PineconeService = PineconeService()) {
        self.referenceIdentifier = referenceIdentifier
        self.pineconeService = pineconeService
        super.init()
        Task {
            await loadInitialItems()
        }
    }
    
    override func loadMoreItems(reset: Bool = false) async {
        isLoading = true
        do {
            let similarVideos = try await pineconeService.findSimilarByIdentifier(referenceIdentifier)
            
            let similarItems = similarVideos.map { result in
                SimilarFeedItem(searchResult: result)
            }
            
            if reset {
                items = similarItems
            } else {
                items.append(contentsOf: similarItems)
            }
            
            hasMoreItems = false // We only get one page of similar videos
            errorMessage = nil
        } catch {
            Logger.network.error("Failed to load similar videos: \(error.localizedDescription)")
            errorMessage = "Failed to load similar videos: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    override func selectItem(_ item: SimilarFeedItem) {
        self.selectedItem = item
    }
}