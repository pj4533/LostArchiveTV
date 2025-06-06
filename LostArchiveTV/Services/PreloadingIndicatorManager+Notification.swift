import Foundation
import Combine

extension PreloadingIndicatorManager {
    /// Receive cache status change notifications that drive the indicator
    func setupCacheStatusObserver() {
        // Listen for cache status changes using Combine
        TransitionPreloadManager.cacheStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStateFromTransitionManager()
            }
            .store(in: &cancellables)
    }
    
    /// Update indicator state based on the TransitionManager's nextVideoReady state
    @MainActor
    func updateStateFromTransitionManager() {
        // Get the main VideoPlayerViewModel's TransitionManager from ContentView
        // We need to ensure we're using the same shared instance
        if let videoPlayerViewModel = SharedViewModelProvider.shared.videoPlayerViewModel,
           let transitionManager = videoPlayerViewModel.transitionManager {
            // TransitionManager's nextVideoReady property directly drives the first indicator dot
            if transitionManager.nextVideoReady {
                state = .preloaded
            } else if state != .notPreloading {
                // If already in a preloading state, stay in preloading state
                state = .preloading
            }
        }
    }
}