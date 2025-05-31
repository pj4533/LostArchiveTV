import Foundation
import OSLog
import Combine

extension VideoCacheService {
    /// Publisher for preloading status changes
    nonisolated static let preloadingStatusPublisher = PassthroughSubject<PreloadingStatus, Never>()
    
    /// Enum for preloading status
    enum PreloadingStatus {
        case started
        case completed
    }
    
    /// Notifies the system that caching has started
    func notifyCachingStarted() {
        Task { @MainActor in
            Logger.caching.info("VideoCacheService: Broadcasting caching started notification")
            VideoCacheService.preloadingStatusPublisher.send(.started)
        }
    }
    
    /// Notifies the system that caching has completed
    func notifyCachingCompleted() {
        Task { @MainActor in
            Logger.caching.info("VideoCacheService: Broadcasting caching completed notification")
            VideoCacheService.preloadingStatusPublisher.send(.completed)
        }
    }
}