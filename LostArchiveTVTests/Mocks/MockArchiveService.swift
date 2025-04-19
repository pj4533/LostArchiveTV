//
//  MockArchiveService.swift
//  LostArchiveTVTests
//
//  Created by Claude on 4/19/25.
//

import Foundation
@testable import LostArchiveTV

// Since we can't inherit from actor ArchiveService, we'll implement the same interface
actor MockArchiveService {
    var mockIdentifiers: [String] = ["test1", "test2", "test3"]
    var mockMetadata: ArchiveMetadata = ArchiveMetadata(
        files: [
            ArchiveFile(name: "test.mp4", format: "MPEG4", size: "1000000", length: "120")
        ],
        metadata: ItemMetadata(identifier: "test1", title: "Test Video", description: "Test Description")
    )
    var shouldThrowError = false
    var errorToThrow = NSError(domain: "MockArchiveService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
    
    func loadArchiveIdentifiers() async throws -> [String] {
        if shouldThrowError {
            throw errorToThrow
        }
        return mockIdentifiers
    }
    
    func fetchMetadata(for identifier: String) async throws -> ArchiveMetadata {
        if shouldThrowError {
            throw errorToThrow
        }
        return mockMetadata
    }
    
    func getRandomIdentifier(from identifiers: [String]) -> String? {
        if shouldThrowError || identifiers.isEmpty {
            return nil
        }
        return identifiers.first
    }
    
    func findPlayableFiles(in metadata: ArchiveMetadata) -> [ArchiveFile] {
        let mp4Files = metadata.files.filter { $0.format == "MPEG4" || ($0.name.hasSuffix(".mp4")) }
        return mp4Files
    }
    
    func getFileDownloadURL(for file: ArchiveFile, identifier: String) -> URL? {
        if shouldThrowError {
            return nil
        }
        return URL(string: "https://example.com/\(identifier)/\(file.name)")
    }
    
    func estimateDuration(fromFile file: ArchiveFile) -> Double {
        return 120.0
    }
}