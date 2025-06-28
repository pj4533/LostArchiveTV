import Foundation
import OSLog

extension VideoCacheManager {
    /// Returns an array of CacheStatus values representing the status of upcoming videos
    /// The first item is the first video in the cache after the current video, and so on
    /// - Parameter currentVideoIdentifier: The identifier of the current video being played
    /// - Returns: An array of CacheStatus values (up to 3)
    @MainActor
    func getCacheStatuses(currentVideoIdentifier: String, transitionManager: VideoTransitionManager? = nil) async -> [CacheStatus] {
        // Get current cache state
        let cachedVideos = await self.getCachedVideos()
        let cacheCount = cachedVideos.count

        // Initialize default status array
        var statuses: [CacheStatus] = [.notCached, .notCached, .notCached]
        
        // CRITICAL: The first circle (next video) should ONLY be green if transitionManager.nextVideoReady is true
        // This ensures perfect consistency between the UI indicator and actual swipe behavior
        let isNextVideoReady = transitionManager?.nextVideoReady ?? false
        
        // First indicator shows if next video is actually ready to play (solid green)
        if isNextVideoReady {
            statuses[0] = .preloaded
        } else if cacheCount > 0 {
            // If not ready to swipe but we have cached videos, show as cached (green outline)
            statuses[0] = .cached
        }
        
        // The other indicators show if videos are in the cache (green outline)
        if cacheCount > 1 {
            statuses[1] = .cached
        }
        
        if cacheCount > 2 {
            statuses[2] = .cached
        }

        // Log complete status information including detailed state
        let statusSymbols = statuses.map { status -> String in
            switch status {
                case .preloaded: return "●" // solid circle
                case .cached: return "○"    // outline 
                case .notCached: return "▢" // empty box
            }
        }
        let statusIndicators = "[\(statusSymbols.joined(separator: " "))]"
        
        Logger.caching.info("📊 CACHE STATUS: \(cacheCount)/3 videos cached, next video ready: \(isNextVideoReady), indicators: \(statusIndicators)")
        
        // Add extra logging when there's a potential mismatch
        if statuses.count > 0 && statuses[0] == .preloaded && !isNextVideoReady {
            Logger.caching.warning("⚠️ MISMATCH RISK: First indicator is green but nextVideoReady=false")
        } else if statuses.count > 0 && statuses[0] != .preloaded && isNextVideoReady {
            Logger.caching.warning("⚠️ MISMATCH RISK: nextVideoReady=true but first indicator is not green")
        }
        
        return statuses
    }
}