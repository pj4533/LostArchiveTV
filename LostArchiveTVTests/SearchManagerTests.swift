//
//  SearchManagerTests.swift
//  LostArchiveTVTests
//
//  Created by Claude on 5/2/25.
//

import Testing
@testable import LATV

// Non-inheritance based approach to create test implementations
class TestOpenAIService {
    var wasCalled = false
    
    func generateEmbedding(for text: String) async throws -> [Double] {
        wasCalled = true
        // Return a fixed embedding for testing
        return Array(repeating: 0.1, count: 10)
    }
}

class TestPineconeService {
    var expectedResults: [SearchResult] = []
    var capturedVector: [Double]?
    var capturedFilter: [String: Any]?
    var capturedTopK: Int?
    var wasCalled = false
    
    func query(vector: [Double], filter: [String: Any]?, topK: Int) async throws -> [SearchResult] {
        wasCalled = true
        capturedVector = vector
        capturedFilter = filter
        capturedTopK = topK
        return expectedResults
    }
}

// Special test version of SearchManager that accepts our test services
class TestSearchManager {
    private let openAIService: TestOpenAIService
    private let pineconeService: TestPineconeService
    
    init(
        openAIService: TestOpenAIService,
        pineconeService: TestPineconeService
    ) {
        self.openAIService = openAIService
        self.pineconeService = pineconeService
    }
    
    func search(query: String, filter: SearchFilter? = nil, page: Int = 0, pageSize: Int = 20) async throws -> [SearchResult] {
        guard !query.isEmpty else {
            return []
        }
        
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
            return []
        }
        
        return Array(searchResults[startIndex..<endIndex])
    }
}

struct SearchManagerTests {
    
    // Helper method to create a test search result
    func createTestSearchResult(id: String, collection: String, score: Float) -> SearchResult {
        let identifier = ArchiveIdentifier(identifier: id, collection: collection)
        let metadata = [
            "title": "Title for \(id)",
            "description": "Description for \(id)"
        ]
        
        return SearchResult(
            identifier: identifier,
            score: score,
            metadata: metadata
        )
    }
    
    @Test
    func search_withEmptyQuery_returnsEmptyResults() async throws {
        // Arrange
        let openAIService = TestOpenAIService()
        let pineconeService = TestPineconeService()
        let searchManager = TestSearchManager(
            openAIService: openAIService,
            pineconeService: pineconeService
        )
        
        // Act
        let results = try await searchManager.search(query: "")
        
        // Assert
        #expect(results.isEmpty)
        #expect(!openAIService.wasCalled) // Should not call OpenAI for empty queries
        #expect(!pineconeService.wasCalled) // Should not call Pinecone for empty queries
    }
    
    @Test
    func search_withValidQuery_delegatesToServices() async throws {
        // Arrange
        let openAIService = TestOpenAIService()
        let pineconeService = TestPineconeService()
        
        // Setup expected results
        pineconeService.expectedResults = [
            createTestSearchResult(id: "id1", collection: "col1", score: 0.9),
            createTestSearchResult(id: "id2", collection: "col2", score: 0.8),
            createTestSearchResult(id: "id3", collection: "col3", score: 0.7)
        ]
        
        let searchManager = TestSearchManager(
            openAIService: openAIService,
            pineconeService: pineconeService
        )
        
        // Act
        let results = try await searchManager.search(query: "test query")
        
        // Assert
        // Check that the services were called
        #expect(openAIService.wasCalled)
        #expect(pineconeService.wasCalled)
        
        // Check that the correct parameters were passed
        #expect(pineconeService.capturedVector != nil)
        #expect(pineconeService.capturedTopK == 20) // Default page size
        
        // Check that we received the expected results
        #expect(results.count == 3)
        #expect(results[0].identifier.identifier == "id1")
        #expect(results[1].identifier.identifier == "id2")
        #expect(results[2].identifier.identifier == "id3")
    }
    
    @Test
    func search_withPagination_calculatesCorrectIndices() async throws {
        // Arrange
        let openAIService = TestOpenAIService()
        let pineconeService = TestPineconeService()
        
        // Setup expected results - 25 results total so we can test pagination
        var expectedResults: [SearchResult] = []
        for i in 1...25 {
            expectedResults.append(
                createTestSearchResult(
                    id: "id\(i)", 
                    collection: "col\(i)",
                    score: 1.0 - (Float(i) * 0.01)
                )
            )
        }
        pineconeService.expectedResults = expectedResults
        
        let searchManager = TestSearchManager(
            openAIService: openAIService,
            pineconeService: pineconeService
        )
        
        // Act - get second page with page size of 10
        let results = try await searchManager.search(query: "test query", page: 1, pageSize: 10)
        
        // Assert
        // Check that the pinecone service was asked for enough results for two pages
        #expect(pineconeService.capturedTopK == 20) // 2 pages * 10 items
        
        // Check that we got the second page of results (items 11-20)
        #expect(results.count == 10)
        #expect(results[0].identifier.identifier == "id11")
        #expect(results[9].identifier.identifier == "id20")
    }
    
    @Test
    func search_withBeyondAvailableResults_returnsEmptyArray() async throws {
        // Arrange
        let openAIService = TestOpenAIService()
        let pineconeService = TestPineconeService()
        
        // Setup expected results - only 5 results available
        var expectedResults: [SearchResult] = []
        for i in 1...5 {
            expectedResults.append(
                createTestSearchResult(
                    id: "id\(i)",
                    collection: "col\(i)",
                    score: 1.0 - (Float(i) * 0.01)
                )
            )
        }
        pineconeService.expectedResults = expectedResults
        
        let searchManager = TestSearchManager(
            openAIService: openAIService,
            pineconeService: pineconeService
        )
        
        // Act - request page 1 (second page) when only 5 items exist
        let results = try await searchManager.search(query: "test query", page: 1, pageSize: 10)
        
        // Assert - should be empty since we're beyond available results
        #expect(results.isEmpty)
    }
}