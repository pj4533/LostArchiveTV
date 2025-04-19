//
//  MockVideoCacheManager.swift
//  LostArchiveTVTests
//
//  Created by Claude on 4/19/25.
//

import Foundation
import AVKit
@testable import LostArchiveTV

// Since we can't inherit from VideoCacheManager actor, we'll implement the same interface
actor MockVideoCacheManager {
    var mockCachedVideos: [CachedVideo] = []
    var mockMaxCacheSize: Int = 3
    
    func getCachedVideos() -> [CachedVideo] {
        return mockCachedVideos
    }
    
    func addCachedVideo(_ video: CachedVideo) {
        mockCachedVideos.append(video)
    }
    
    func removeFirstCachedVideo() -> CachedVideo? {
        guard !mockCachedVideos.isEmpty else { return nil }
        return mockCachedVideos.removeFirst()
    }
    
    func clearCache() {
        mockCachedVideos.removeAll()
    }
    
    func getMaxCacheSize() -> Int {
        return mockMaxCacheSize
    }
    
    func cacheCount() -> Int {
        return mockCachedVideos.count
    }
    
    func isCacheEmpty() -> Bool {
        return mockCachedVideos.isEmpty
    }
}