import Foundation
import OSLog

extension PreloadService {
    /// Notifies the system that preloading has started
    func notifyPreloadingStarted() {
        Task { @MainActor in
            Logger.caching.info("PreloadService: Broadcasting preloading started notification")
            NotificationCenter.default.post(name: .preloadingStarted, object: nil)
        }
    }
    
    /// Notifies the system that preloading has completed
    func notifyPreloadingCompleted() {
        Task { @MainActor in
            Logger.caching.info("PreloadService: Broadcasting preloading completed notification")
            NotificationCenter.default.post(name: .preloadingCompleted, object: nil)
        }
    }
}