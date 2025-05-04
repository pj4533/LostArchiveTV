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
    
    func search(queryContext: SearchQueryContext, page: Int = 0, pageSize: Int = 20) async throws -> [SearchResult] {
        // Simple branching based on context type
        if let identifier = queryContext.similarToIdentifier {
            // Similar search - use the identifier
            return try await searchSimilar(identifier: identifier, page: page, pageSize: pageSize)
        } else if let query = queryContext.query {
            // Text search - use the query string
            return try await searchByText(query: query, filter: queryContext.filter, page: page, pageSize: pageSize)
        } else {
            // Invalid context
            Logger.caching.error("Invalid search context - neither query nor similarToIdentifier is present")
            return []
        }
    }
    
    // Original text-based search implementation
    private func searchByText(query: String, filter: SearchFilter? = nil, page: Int = 0, pageSize: Int = 20) async throws -> [SearchResult] {
        guard !query.isEmpty else {
            Logger.caching.info("Empty search query, returning empty results")
            return []
        }
        
        Logger.caching.info("Starting text search for query: \(query), page: \(page), pageSize: \(pageSize)")
        
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
        
        Logger.caching.info("Text search complete, returning page \(page) with \(pageResults.count) results")
        
        return pageResults
    }
    
    // Similar search implementation using identifier
    private func searchSimilar(identifier: String, page: Int = 0, pageSize: Int = 20) async throws -> [SearchResult] {
        Logger.caching.info("Starting similar search for identifier: \(identifier), page: \(page), pageSize: \(pageSize)")
        
        // Calculate offset based on page and page size
        let offset = page * pageSize
        
        // Use the updated findSimilarByIdentifier with pagination support
        let results = try await pineconeService.findSimilarByIdentifier(
            identifier,
            topK: pageSize,
            offset: offset
        )
        
        Logger.caching.info("Similar search complete, returning \(results.count) results for page \(page)")
        
        return results
    }
    
    // For backward compatibility
    func search(query: String, filter: SearchFilter? = nil, page: Int = 0, pageSize: Int = 20) async throws -> [SearchResult] {
        let context = SearchQueryContext(query: query, filter: filter)
        return try await search(queryContext: context, page: page, pageSize: pageSize)
    }
}