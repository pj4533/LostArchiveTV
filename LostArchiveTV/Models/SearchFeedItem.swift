import Foundation
import OSLog

struct SearchFeedItem: FeedItem {
    let searchResult: SearchResult
    let searchViewModel: SearchViewModel
    
    var id: String { searchResult.identifier.identifier }
    var title: String { searchResult.title }
    var description: String? { searchResult.description }
    var thumbnailURL: URL? { URL(string: "https://archive.org/services/img/\(searchResult.identifier.identifier)") }
    var metadata: [String: String] {
        var result: [String: String] = [:]
        result["Score"] = String(format: "%.2f", searchResult.score)
        if let year = searchResult.year {
            result["Year"] = String(year)
        }
        if !searchResult.collections.isEmpty {
            result["Collection"] = searchResult.collections.first!
        }
        
        // Get file count directly from the search view model's cache
        if let cachedFileCount = searchViewModel.getCachedFileCount(for: searchResult.identifier.identifier) {
            result["Files"] = cachedFileCount == 1 ? "1 file" : "\(cachedFileCount) files"
            Logger.caching.debug("🔍 DEBUG: SearchFeedItem displaying cached file count for \(searchResult.identifier.identifier): \(cachedFileCount)")
        } else {
            // If not cached, trigger async fetch but don't block the UI
            Task {
                let fileCount = await searchViewModel.fetchFileCount(for: searchResult.identifier.identifier)
                Logger.caching.debug("🔍 DEBUG: SearchFeedItem fetched file count for \(searchResult.identifier.identifier): \(fileCount ?? -1)")
            }
            Logger.caching.debug("🔍 DEBUG: SearchFeedItem no cached file count for \(searchResult.identifier.identifier), triggering async fetch")
        }
        
        return result
    }
}