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
    
    func search(query: String, filter: SearchFilter? = nil) async throws -> [SearchResult] {
        guard !query.isEmpty else {
            Logger.caching.info("Empty search query, returning empty results")
            return []
        }
        
        Logger.caching.info("Starting search for query: \(query)")
        
        // Generate embedding for the query
        let embedding = try await openAIService.generateEmbedding(for: query)
        
        // Convert filter to Pinecone format
        let pineconeFilter = filter?.toPineconeFilter()
        
        // Query Pinecone
        let searchResults = try await pineconeService.query(
            vector: embedding,
            filter: pineconeFilter,
            topK: 20
        )
        
        Logger.caching.info("Search complete, found \(searchResults.count) results")
        
        return searchResults
    }
}