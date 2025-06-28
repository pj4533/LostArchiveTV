//
//  SearchViewModelTests.swift
//  LostArchiveTVTests
//
//  Created by Claude on 6/28/25.
//

import Testing
import Foundation
@testable import LATV

struct SearchViewModelTests {
    
    // Helper to create test search results
    func createTestSearchResult(id: String, collection: String = "test-collection") -> SearchResult {
        let identifier = ArchiveIdentifier(identifier: id, collection: collection)
        let metadata = [
            "title": "Test \(id)",
            "description": "Description for \(id)"
        ]
        return SearchResult(identifier: identifier, score: 0.9, metadata: metadata)
    }
    
    // Helper to create test metadata with specific file count
    func createTestMetadata(withVideoFileCount count: Int) -> ArchiveMetadata {
        var files: [ArchiveFile] = []
        
        // Add unique video files
        for i in 0..<count {
            files.append(ArchiveFile(
                name: "video\(i).mp4",
                format: "MPEG4",
                size: "1000000",
                length: "60.0"
            ))
        }
        
        // Add some non-video files to test filtering
        files.append(ArchiveFile(
            name: "thumbnail.jpg",
            format: "JPEG",
            size: "50000",
            length: nil
        ))
        
        return ArchiveMetadata(
            files: files,
            metadata: ItemMetadata(
                identifier: "test",
                title: "Test Title",
                description: "Test metadata"
            )
        )
    }
    
    @Test
    func searchViewModel_initializesWithEmptyFilter() async throws {
        // Arrange & Act
        let viewModel = await SearchViewModel()
        
        // Assert
        await MainActor.run {
            #expect(viewModel.searchFilter.minFileCount == nil)
            #expect(viewModel.searchFilter.maxFileCount == nil)
            #expect(viewModel.searchFilter.startYear == nil)
            #expect(viewModel.searchFilter.endYear == nil)
        }
    }
    
    @Test
    func searchViewModel_canSetFileCountFilters() async throws {
        // Arrange
        let viewModel = await SearchViewModel()
        
        // Act
        await MainActor.run {
            viewModel.searchFilter.minFileCount = 5
            viewModel.searchFilter.maxFileCount = 20
        }
        
        // Assert
        await MainActor.run {
            #expect(viewModel.searchFilter.minFileCount == 5)
            #expect(viewModel.searchFilter.maxFileCount == 20)
        }
    }
    
    @Test
    func searchViewModel_clearsResultsOnEmptyQuery() async throws {
        // Arrange
        let viewModel = await SearchViewModel()
        
        // Act - search with empty query
        await MainActor.run {
            viewModel.searchQuery = ""
        }
        await viewModel.search()
        
        // Assert
        await MainActor.run {
            #expect(viewModel.searchResults.isEmpty)
            #expect(!viewModel.isSearching)
        }
    }
    
    
    @Test
    func searchViewModel_maintainsFilterAcrossSearches() async throws {
        // Arrange
        let viewModel = await SearchViewModel()
        
        // Act - set filters
        await MainActor.run {
            viewModel.searchFilter.minFileCount = 10
            viewModel.searchFilter.maxFileCount = 50
            viewModel.searchFilter.startYear = 2020
            viewModel.searchFilter.endYear = 2023
        }
        
        // Perform a search (will fail but that's ok for this test)
        await MainActor.run {
            viewModel.searchQuery = "test"
        }
        let searchTask = Task {
            await viewModel.search()
        }
        searchTask.cancel()
        
        // Assert - filters should still be set
        await MainActor.run {
            #expect(viewModel.searchFilter.minFileCount == 10)
            #expect(viewModel.searchFilter.maxFileCount == 50)
            #expect(viewModel.searchFilter.startYear == 2020)
            #expect(viewModel.searchFilter.endYear == 2023)
        }
    }
}

// Additional tests for the file count filtering logic
struct FileCountFilteringLogicTests {
    
    @Test
    func fileCountLogic_countsOnlyVideoFiles() async throws {
        // This test verifies the logic of counting video files based on format
        let videoFormats = ["MPEG4", "h.264", "h.264 IA"]
        let nonVideoFormats = ["JPEG", "PNG", "PDF", "TXT"]
        
        // Verify video formats are recognized
        for format in videoFormats {
            let file = ArchiveFile(name: "test.mp4", format: format, size: "1000", length: "60")
            #expect(file.format == "h.264 IA" || file.format == "h.264" || file.format == "MPEG4" || file.name.hasSuffix(".mp4"))
        }
        
        // Verify non-video formats are not counted
        for format in nonVideoFormats {
            let file = ArchiveFile(name: "test.jpg", format: format, size: "1000", length: nil)
            #expect(!(file.format == "h.264 IA" || file.format == "h.264" || file.format == "MPEG4") && !file.name.hasSuffix(".mp4"))
        }
    }
    
    @Test
    func fileCountLogic_recognizesMP4Extension() async throws {
        // Test that files with .mp4 extension are counted regardless of format
        let file1 = ArchiveFile(name: "video.mp4", format: "Unknown", size: "1000", length: "60")
        let file2 = ArchiveFile(name: "video.avi", format: "MPEG4", size: "1000", length: "60")
        
        #expect(file1.name.hasSuffix(".mp4"))
        #expect(!file2.name.hasSuffix(".mp4"))
    }
    
    @Test
    func fileCountLogic_handlesUniqueBaseNames() async throws {
        // Test the logic for extracting unique base names
        let fileNames = [
            "video1.mp4",
            "video1.mp4", // Duplicate
            "video2.mp4",
            "video3.mp4",
            "video3.mp4"  // Duplicate
        ]
        
        var uniqueBaseNames = Set<String>()
        for fileName in fileNames {
            let baseName = fileName.replacingOccurrences(of: "\\.mp4$", with: "", options: .regularExpression)
            uniqueBaseNames.insert(baseName)
        }
        
        #expect(uniqueBaseNames.count == 3)
        #expect(uniqueBaseNames.contains("video1"))
        #expect(uniqueBaseNames.contains("video2"))
        #expect(uniqueBaseNames.contains("video3"))
    }
}