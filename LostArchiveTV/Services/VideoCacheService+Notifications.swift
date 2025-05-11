import Foundation
import OSLog

extension VideoCacheService {
    /// Notifies the system that caching has started
    func notifyCachingStarted() {
        Task { @MainActor in
            Logger.caching.info("VideoCacheService: Broadcasting caching started notification")
            NotificationCenter.default.post(name: .preloadingStarted, object: nil)
        }
    }
    
    /// Notifies the system that caching has completed
    func notifyCachingCompleted() {
        Task { @MainActor in
            Logger.caching.info("VideoCacheService: Broadcasting caching completed notification")
            NotificationCenter.default.post(name: .preloadingCompleted, object: nil)
        }
    }
}