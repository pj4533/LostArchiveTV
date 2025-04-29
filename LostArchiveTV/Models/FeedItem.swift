import Foundation

protocol FeedItem: Identifiable {
    var id: String { get }
    var title: String { get }
    var description: String? { get }
    var thumbnailURL: URL? { get }
    var metadata: [String: String] { get }
}

struct FavoritesFeedItem: FeedItem {
    let cachedVideo: CachedVideo
    
    var id: String { cachedVideo.id }
    var title: String { cachedVideo.title }
    var description: String? { cachedVideo.description }
    var thumbnailURL: URL? { cachedVideo.thumbnailURL }
    var metadata: [String: String] {
        var result: [String: String] = [:]
        // Add collection information
        result["Collection"] = cachedVideo.collection
        
        // We could add more metadata in the future if ItemMetadata has more fields
        return result
    }
}

struct SearchFeedItem: FeedItem {
    let searchResult: SearchResult
    
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
        return result
    }
}