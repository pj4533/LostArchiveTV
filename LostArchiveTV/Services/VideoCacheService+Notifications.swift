import Foundation
import OSLog
import Combine

extension VideoCacheService {
    /// Publisher for preloading status changes
    static var preloadingStatusPublisher = PassthroughSubject<PreloadingStatus, Never>()
    
    /// Enum for preloading status
    enum PreloadingStatus: Equatable {
        case started
        case completed
    }
    
    /// Notifies the system that caching has started
    func notifyCachingStarted() async {
        Logger.caching.info("VideoCacheService: Broadcasting caching started notification")
        Logger.preloading.notice("📡 NOTIFICATION SENT: Sending .started through preloadingStatusPublisher")
        await MainActor.run {
            VideoCacheService.preloadingStatusPublisher.send(.started)
        }
    }
    
    /// Notifies the system that caching has completed
    func notifyCachingCompleted() async {
        Logger.caching.info("VideoCacheService: Broadcasting caching completed notification")
        Logger.preloading.notice("📡 NOTIFICATION SENT: Sending .completed through preloadingStatusPublisher")
        await MainActor.run {
            VideoCacheService.preloadingStatusPublisher.send(.completed)
        }
    }
}