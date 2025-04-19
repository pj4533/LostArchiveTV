//
//  MockPreloadService.swift
//  LostArchiveTVTests
//
//  Created by Claude on 4/19/25.
//

import Foundation
@testable import LostArchiveTV

// Since we can't inherit from PreloadService actor, we'll implement the same interface
actor MockPreloadService {
    var ensureVideosAreCachedCalled = false
    var preloadRandomVideoCalled = false
    var cancelPreloadingCalled = false
    var shouldThrowError = false
    var errorToThrow = NSError(domain: "MockPreloadService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
    
    func ensureVideosAreCached(cacheManager: MockVideoCacheManager, archiveService: MockArchiveService, identifiers: [String]) async {
        ensureVideosAreCachedCalled = true
    }
    
    func preloadRandomVideo(cacheManager: MockVideoCacheManager, archiveService: MockArchiveService, identifiers: [String]) async throws {
        preloadRandomVideoCalled = true
        if shouldThrowError {
            throw errorToThrow
        }
    }
    
    func cancelPreloading() {
        cancelPreloadingCalled = true
    }
}