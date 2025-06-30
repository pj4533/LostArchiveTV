//
//  SearchViewModelUnavailableContentTests.swift
//  LostArchiveTVTests
//
//  Created by Claude on 6/30/25.
//

import Testing
import Foundation
@testable import LostArchiveTV

@Suite("SearchViewModel Unavailable Content Tests")
struct SearchViewModelUnavailableContentTests {
    
    @Test("Content becomes unavailable after fetch failure")
    @MainActor
    func testContentBecomesUnavailableAfterFetchFailure() async throws {
        // Arrange
        let mockArchiveService = MockArchiveServiceForUnavailable()
        let searchViewModel = SearchViewModel(
            videoLoadingService: VideoLoadingService(
                archiveService: mockArchiveService,
                cacheManager: VideoCacheManager()
            )
        )
        let testIdentifier = "test-unavailable-identifier"
        
        // Act - Fetch file count which should fail with contentUnavailable
        let fileCount = await searchViewModel.fetchFileCount(for: testIdentifier)
        
        // Assert
        #expect(fileCount == nil)
        #expect(searchViewModel.isContentUnavailable(for: testIdentifier) == true)
        #expect(searchViewModel.getCachedFileCount(for: testIdentifier) == nil)
    }
    
    @Test("Available content is not marked as unavailable")
    @MainActor
    func testAvailableContentNotMarkedAsUnavailable() async throws {
        // Arrange
        let searchViewModel = SearchViewModel()
        let testIdentifier = "test-available-identifier"
        
        // Act - Check an identifier that hasn't been fetched
        let isUnavailable = searchViewModel.isContentUnavailable(for: testIdentifier)
        
        // Assert
        #expect(isUnavailable == false)
    }
    
    @Test("Search clears unavailable content cache")
    @MainActor 
    func testSearchClearsUnavailableContentCache() async throws {
        // Arrange
        let mockArchiveService = MockArchiveServiceForUnavailable()
        let searchViewModel = SearchViewModel(
            videoLoadingService: VideoLoadingService(
                archiveService: mockArchiveService,
                cacheManager: VideoCacheManager()
            )
        )
        let testIdentifier = "test-identifier"
        
        // First, make content unavailable
        _ = await searchViewModel.fetchFileCount(for: testIdentifier)
        #expect(searchViewModel.isContentUnavailable(for: testIdentifier) == true)
        
        // Act - Set search query and trigger search (which clears cache)
        searchViewModel.searchQuery = "test query"
        await searchViewModel.search()
        
        // Assert - Cache should be cleared
        #expect(searchViewModel.isContentUnavailable(for: testIdentifier) == false)
        #expect(searchViewModel.getCachedFileCount(for: testIdentifier) == nil)
    }
}

// Mock archive service that throws contentUnavailable error
class MockArchiveServiceForUnavailable: ArchiveService {
    override func fetchMetadata(for identifier: String) async throws -> ArchiveMetadata {
        throw NetworkError.contentUnavailable(identifier: identifier)
    }
}