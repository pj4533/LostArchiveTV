import Foundation

struct SearchQueryContext {
    let query: String?
    let filter: SearchFilter?
    let similarToIdentifier: String?
    
    // For text-based searches
    init(query: String, filter: SearchFilter? = nil) {
        self.query = query
        self.filter = filter
        self.similarToIdentifier = nil
    }
    
    // For similar searches
    init(similarToIdentifier: String, filter: SearchFilter? = nil) {
        self.query = nil
        self.filter = filter
        self.similarToIdentifier = similarToIdentifier
    }
    
    var isSimilarSearch: Bool {
        return similarToIdentifier != nil
    }
    
    var isTextSearch: Bool {
        return query != nil
    }
}