import Foundation
import OSLog

extension VideoCacheManager {
    /// Returns an array of CacheStatus values representing the status of upcoming videos
    /// The first item is the first video in the cache after the current video, and so on
    /// - Parameter currentVideoIdentifier: The identifier of the current video being played
    /// - Returns: An array of CacheStatus values (up to 3)
    func getCacheStatuses(currentVideoIdentifier: String) async -> [CacheStatus] {
        // Get current cache state
        let cachedVideos = self.getCachedVideos()
        let cacheCount = cachedVideos.count

        // Simplify the logic:
        // If there's at least one cached video, mark the first as preloaded
        // If there are more cached videos, mark them as cached
        // Otherwise mark as not cached
        var statuses: [CacheStatus] = [.notCached, .notCached, .notCached]

        if cacheCount > 0 {
            // First video in cache is considered "preloaded" (ready to play right away)
            statuses[0] = .preloaded

            // Mark additional cached videos
            if cacheCount > 1 {
                statuses[1] = .cached
            }

            if cacheCount > 2 {
                statuses[2] = .cached
            }

            // Single compact log message
            Logger.caching.debug("Cache status: \(cacheCount)/3 videos cached")
        }

        return statuses
    }
}