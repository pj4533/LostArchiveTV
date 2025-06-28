//
//  SearchFilterTests.swift
//  LostArchiveTVTests
//
//  Created by Claude on 6/28/25.
//

import Testing
@testable import LATV

struct SearchFilterTests {
    
    @Test
    func searchFilter_initializesWithNilValues() async throws {
        // Arrange & Act
        let filter = SearchFilter()
        
        // Assert
        #expect(filter.startYear == nil)
        #expect(filter.endYear == nil)
        #expect(filter.minFileCount == nil)
        #expect(filter.maxFileCount == nil)
    }
    
    @Test
    func searchFilter_storesMinFileCount() async throws {
        // Arrange
        var filter = SearchFilter()
        
        // Act
        filter.minFileCount = 5
        
        // Assert
        #expect(filter.minFileCount == 5)
        #expect(filter.maxFileCount == nil)
    }
    
    @Test
    func searchFilter_storesMaxFileCount() async throws {
        // Arrange
        var filter = SearchFilter()
        
        // Act
        filter.maxFileCount = 20
        
        // Assert
        #expect(filter.minFileCount == nil)
        #expect(filter.maxFileCount == 20)
    }
    
    @Test
    func searchFilter_storesBothFileCountLimits() async throws {
        // Arrange
        var filter = SearchFilter()
        
        // Act
        filter.minFileCount = 3
        filter.maxFileCount = 15
        
        // Assert
        #expect(filter.minFileCount == 3)
        #expect(filter.maxFileCount == 15)
    }
    
    @Test
    func searchFilter_canResetFileCountValues() async throws {
        // Arrange
        var filter = SearchFilter()
        filter.minFileCount = 10
        filter.maxFileCount = 50
        
        // Act
        filter.minFileCount = nil
        filter.maxFileCount = nil
        
        // Assert
        #expect(filter.minFileCount == nil)
        #expect(filter.maxFileCount == nil)
    }
    
    @Test
    func searchFilter_maintainsIndependentProperties() async throws {
        // Arrange
        var filter = SearchFilter()
        
        // Act
        filter.startYear = 2020
        filter.endYear = 2023
        filter.minFileCount = 2
        filter.maxFileCount = 10
        
        // Assert - all properties should be independently set
        #expect(filter.startYear == 2020)
        #expect(filter.endYear == 2023)
        #expect(filter.minFileCount == 2)
        #expect(filter.maxFileCount == 10)
    }
    
    @Test
    func searchFilter_toPineconeFilter_ignoresFileCountProperties() async throws {
        // Arrange
        var filter = SearchFilter()
        filter.minFileCount = 5
        filter.maxFileCount = 20
        
        // Act
        let pineconeFilter = filter.toPineconeFilter()
        
        // Assert - file count filters should not be included in Pinecone filter
        #expect(pineconeFilter == nil)
    }
    
    @Test
    func searchFilter_toPineconeFilter_combinesWithYearFilters() async throws {
        // Arrange
        var filter = SearchFilter()
        filter.startYear = 2020
        filter.endYear = 2023
        filter.minFileCount = 5
        filter.maxFileCount = 20
        
        // Act
        let pineconeFilter = filter.toPineconeFilter()
        
        // Assert - only year filters should be in Pinecone filter
        #expect(pineconeFilter != nil)
        if let filterDict = pineconeFilter,
           let andClause = filterDict["$and"] as? [[String: Any]] {
            #expect(andClause.count == 1)
            #expect(andClause[0]["year"] != nil)
        } else {
            Issue.record("Expected Pinecone filter structure not found")
        }
    }
}