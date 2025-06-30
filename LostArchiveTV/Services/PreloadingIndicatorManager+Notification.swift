import Foundation
import Combine

extension PreloadingIndicatorManager {
    /// Receive buffer status change notifications that drive the indicator
    func setupBufferStateObserver() {
        // Listen for buffer status changes using Combine
        TransitionPreloadManager.bufferStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] bufferState in
                self?.updateStateFromTransitionManager(bufferState: bufferState)
            }
            .store(in: &cancellables)
    }
    
    /// Update indicator state based on the buffer state
    @MainActor
    func updateStateFromTransitionManager(bufferState: BufferState) {
        // Update indicator state based on buffer state
        // Show green (preloaded) when buffer is ready (good or excellent)
        if bufferState.isReady {
            // Buffer is ready, show green
            state = .preloaded
        } else {
            // Not ready yet, show preloading state
            if state != .notPreloading {
                state = .preloading
            }
        }
    }
}