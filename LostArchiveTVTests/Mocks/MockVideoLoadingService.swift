//
//  MockVideoLoadingService.swift
//  LostArchiveTVTests
//
//  Created by Claude on 4/19/25.
//

import Foundation
import AVKit
@testable import LostArchiveTV

// Since we can't inherit from VideoLoadingService actor, we'll implement the same interface
actor MockVideoLoadingService {
    var mockIdentifiers: [String] = ["test1", "test2", "test3"]
    var mockVideo: (identifier: String, title: String, description: String, asset: AVAsset, startPosition: Double)
    var loadIdentifiersCalled = false
    var loadRandomVideoCalled = false
    var loadFreshRandomVideoCalled = false
    var shouldThrowError = false
    var errorToThrow = NSError(domain: "MockVideoLoadingService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
    
    init() {
        self.mockVideo = (
            identifier: "test1",
            title: "Test Video",
            description: "Test Description",
            asset: AVURLAsset(url: URL(string: "https://example.com/test1/test.mp4")!),
            startPosition: 10.0
        )
    }
    
    func loadIdentifiers() async throws -> [String] {
        loadIdentifiersCalled = true
        if shouldThrowError {
            throw errorToThrow
        }
        return mockIdentifiers
    }
    
    func loadRandomVideo() async throws -> (identifier: String, title: String, description: String, asset: AVAsset, startPosition: Double) {
        loadRandomVideoCalled = true
        if shouldThrowError {
            throw errorToThrow
        }
        return mockVideo
    }
}