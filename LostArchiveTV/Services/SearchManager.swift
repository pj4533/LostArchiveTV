import Foundation
import OSLog

class SearchManager {
    private let openAIService: OpenAIService
    private let pineconeService: PineconeService
    
    
    init(
        openAIService: OpenAIService = OpenAIService(),
        pineconeService: PineconeService = PineconeService()
    ) {
        self.openAIService = openAIService
        self.pineconeService = pineconeService
    }
    
    func search(query: String, filter: SearchFilter? = nil, page: Int = 0, pageSize: Int = 20) async throws -> [SearchResult] {
        guard !query.isEmpty else {
            Logger.caching.info("Empty search query, returning empty results")
            return []
        }
        
        Logger.caching.info("Starting search for query: \(query), page: \(page), pageSize: \(pageSize)")
        
        // Generate embedding for the query
        let embedding = try await openAIService.generateEmbedding(for: query)
        
        // Convert filter to Pinecone format
        let pineconeFilter = filter?.toPineconeFilter()
        
        // Calculate how many results to fetch based on page and pageSize
        let totalToFetch = (page + 1) * pageSize
        
        // Query Pinecone for the total number of results we need
        let searchResults = try await pineconeService.query(
            vector: embedding,
            filter: pineconeFilter,
            topK: totalToFetch
        )
        
        // Calculate the slice to return based on the current page
        let startIndex = page * pageSize
        let endIndex = min(startIndex + pageSize, searchResults.count)
        
        // If we're beyond available results, return empty array
        if startIndex >= searchResults.count {
            Logger.caching.info("Page \(page) is beyond available results, returning empty array")
            return []
        }
        
        let pageResults = Array(searchResults[startIndex..<endIndex])
        
        Logger.caching.info("Search complete, returning page \(page) with \(pageResults.count) results")
        
        return pageResults
    }
}