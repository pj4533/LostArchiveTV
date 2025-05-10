import Foundation
import AVFoundation
import OSLog

protocol VideoProvider: AnyObject {
    // Video transition manager for swipe handling and preloading
    var transitionManager: VideoTransitionManager? { get }

    // Get the next video in the sequence (changes the current index)
    func getNextVideo() async -> CachedVideo?

    // Get the previous video in the sequence (changes the current index)
    func getPreviousVideo() async -> CachedVideo?

    // Peek at the next video without changing the index (for preloading)
    func peekNextVideo() async -> CachedVideo?

    // Peek at the previous video without changing the index (for preloading)
    func peekPreviousVideo() async -> CachedVideo?

    // Check if we're at the end of the sequence
    func isAtEndOfHistory() -> Bool

    // Load more items when reaching the end of the sequence
    func loadMoreItemsIfNeeded() async -> Bool

    // Create a cached video from the current state
    func createCachedVideoFromCurrentState() async -> CachedVideo?

    // Add a video to the sequence
    func addVideoToHistory(_ video: CachedVideo)

    // Current video properties
    var player: AVPlayer? { get set }
    var currentIdentifier: String? { get set }
    var currentTitle: String? { get set }
    var currentCollection: String? { get set }
    var currentDescription: String? { get set }
    var currentFilename: String? { get set }

    // Ensure videos are preloaded/cached
    func ensureVideosAreCached() async

    // Pause all background operations (optional)
    func pauseBackgroundOperations() async

    // Resume all background operations (optional)
    func resumeBackgroundOperations() async
}

// Default implementations for VideoProvider methods
extension VideoProvider {
    // Default implementations for navigation
    func updateToNextVideo() {
        // Default implementation is empty - providers should override as needed
        Logger.caching.info("Default updateToNextVideo called - provider should override this")
    }

    func updateToPreviousVideo() {
        // Default implementation is empty - providers should override as needed
        Logger.caching.info("Default updateToPreviousVideo called - provider should override this")
    }

    // Default implementations for background operation control
    func pauseBackgroundOperations() async {
        // Default is empty - subclasses with background operations should override
        Logger.caching.info("🛑 PAUSING BACKGROUND OPERATIONS in \(String(describing: type(of: self)))")

        // Pause the transition manager's operations
        transitionManager?.pausePreloading()
    }

    func resumeBackgroundOperations() async {
        // Default is empty - subclasses with background operations should override
        Logger.caching.info("▶️ RESUMING BACKGROUND OPERATIONS in \(String(describing: type(of: self)))")

        // Resume the transition manager's operations
        transitionManager?.resumePreloading()
    }
}