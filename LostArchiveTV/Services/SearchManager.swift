import Foundation
import OSLog

protocol SearchManagerProtocol {
    func search(query: String, filter: SearchFilter?) async throws -> [SearchResult]
}

class SearchManager: SearchManagerProtocol {
    private let openAIService: OpenAIServiceProtocol
    private let pineconeService: PineconeServiceProtocol
    
    init(
        openAIService: OpenAIServiceProtocol = OpenAIService(),
        pineconeService: PineconeServiceProtocol = PineconeService()
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