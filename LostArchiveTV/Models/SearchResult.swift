import Foundation

struct SearchResult: Identifiable, Equatable {
    let id = UUID()
    let identifier: ArchiveIdentifier
    let score: Float
    let metadata: [String: String]
    
    // Computed properties for UI display
    var title: String { metadata["title"] ?? identifier.identifier }
    var description: String { metadata["description"] ?? "" }
    var year: Int? { 
        guard let yearStr = metadata["year"], let year = Int(yearStr) else { return nil }
        return year
    }
    var collections: [String] {
        guard let collectionsStr = metadata["collection"] else { return [identifier.collection] }
        return collectionsStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }
    
    // Equatable implementation
    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        return lhs.identifier == rhs.identifier &&
               lhs.score == rhs.score &&
               lhs.metadata == rhs.metadata
    }
}

struct SearchFilter {
    var startYear: Int? = nil
    var endYear: Int? = nil
    var minFileCount: Int? = nil
    var maxFileCount: Int? = nil
    
    // Convert filter to Pinecone query format
    func toPineconeFilter() -> [String: Any]? {
        var filter: [String: Any] = [:]
        var filterComponents: [[String: Any]] = []
        
        // Add year range filter if specified
        if let startYear = startYear, let endYear = endYear {
            filterComponents.append(["year": ["$gte": startYear, "$lte": endYear]])
        } else if let startYear = startYear {
            filterComponents.append(["year": ["$gte": startYear]])
        } else if let endYear = endYear {
            filterComponents.append(["year": ["$lte": endYear]])
        }
        
        // If no filters, return nil
        if filterComponents.isEmpty {
            return nil
        }
        
        // Combine filters with $and operator
        filter["$and"] = filterComponents
        return filter
    }
}