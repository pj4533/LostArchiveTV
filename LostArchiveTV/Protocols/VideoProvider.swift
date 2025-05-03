import Foundation
import AVFoundation

protocol VideoProvider: AnyObject {
    // Get the next video in the sequence
    func getNextVideo() async -> CachedVideo?
    
    // Get the previous video in the sequence
    func getPreviousVideo() async -> CachedVideo?
    
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
    
    // Ensure videos are preloaded/cached
    func ensureVideosAreCached() async
}