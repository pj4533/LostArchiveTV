import Foundation

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