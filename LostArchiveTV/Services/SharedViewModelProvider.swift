import SwiftUI

/// A single shared instance that provides access to the main view models
/// This ensures the RetroEdgePreloadIndicator has access to the same instances as the rest of the app
class SharedViewModelProvider {
    static let shared = SharedViewModelProvider()
    
    // Store a reference to the main VideoPlayerViewModel when it's created
    weak var videoPlayerViewModel: VideoPlayerViewModel?
    
    private init() {}
}