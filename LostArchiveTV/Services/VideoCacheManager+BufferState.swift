import Foundation
import OSLog

extension VideoCacheManager {
    /// Returns an array of BufferState values representing the status of upcoming videos
    /// The first item is the first video in the cache after the current video, and so on
    /// - Parameter currentVideoIdentifier: The identifier of the current video being played
    /// - Returns: An array of BufferState values (up to 3)
    func getBufferStates(currentVideoIdentifier: String, transitionManager: VideoTransitionManager? = nil) async -> [BufferState] {
        // Get current cache state
        let cachedVideos = self.getCachedVideos()
        let cacheCount = cachedVideos.count

        // Initialize default status array
        var statuses: [BufferState] = [.empty, .empty, .empty]
        
        // CRITICAL: The first circle (next video) should ONLY be green if transitionManager.nextVideoReady is true
        // This ensures perfect consistency between the UI indicator and actual swipe behavior
        let isNextVideoReady = transitionManager?.nextVideoReady ?? false
        
        // First indicator shows if next video is actually ready to play (solid green)
        if isNextVideoReady {
            statuses[0] = .excellent  // Excellent buffer state indicates fully ready
        } else if cacheCount > 0 {
            // If not ready to swipe but we have cached videos, show as good (green outline)
            statuses[0] = .good
        }
        
        // The other indicators show if videos are in the cache (green outline)
        if cacheCount > 1 {
            statuses[1] = .good  // Good buffer state for cached videos
        }
        
        if cacheCount > 2 {
            statuses[2] = .good  // Good buffer state for cached videos
        }

        // Log complete status information including detailed state
        let statusSymbols = statuses.map { status -> String in
            switch status {
                case .excellent: return "●" // solid circle (fully ready)
                case .good: return "○"      // outline (cached but not ready)
                case .empty: return "▢"     // empty box
                default: return "?"
            }
        }
        let statusIndicators = "[\(statusSymbols.joined(separator: " "))]"
        
        Logger.caching.info("📊 CACHE STATUS: \(cacheCount)/3 videos cached, next video ready: \(isNextVideoReady), indicators: \(statusIndicators)")
        
        // Add extra logging when there's a potential mismatch
        if statuses.count > 0 && statuses[0] == .excellent && !isNextVideoReady {
            Logger.caching.warning("⚠️ MISMATCH RISK: First indicator is excellent but nextVideoReady=false")
        } else if statuses.count > 0 && statuses[0] != .excellent && isNextVideoReady {
            Logger.caching.warning("⚠️ MISMATCH RISK: nextVideoReady=true but first indicator is not excellent")
        }
        
        return statuses
    }
}