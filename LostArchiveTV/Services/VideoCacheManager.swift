//
//  VideoCacheManager.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import Foundation
import AVFoundation
import OSLog

actor VideoCacheManager {
    private var cachedVideos: [CachedVideo] = []
    private var maxCachedVideos = 3
    
    func getCachedVideos() -> [CachedVideo] {
        return cachedVideos
    }
    
    func addCachedVideo(_ video: CachedVideo) {
        cachedVideos.append(video)
        Logger.caching.info("Added video to cache: \(video.identifier), cache size: \(self.cachedVideos.count)")
    }
    
    func removeFirstCachedVideo() -> CachedVideo? {
        guard !cachedVideos.isEmpty else { return nil }
        let video = cachedVideos.removeFirst()
        Logger.caching.info("Removed video from cache: \(video.identifier), cache size: \(self.cachedVideos.count)")
        return video
    }
    
    func clearCache() {
        Logger.caching.info("Clearing video cache (\(self.cachedVideos.count) videos)")
        cachedVideos.removeAll()
    }
    
    func getMaxCacheSize() -> Int {
        return maxCachedVideos
    }
    
    func cacheCount() -> Int {
        return cachedVideos.count
    }
    
    func isCacheEmpty() -> Bool {
        return cachedVideos.isEmpty
    }
}
