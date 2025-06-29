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
        // Only show green (preloaded) when buffer is excellent
        switch bufferState {
        case .unknown, .empty, .critical, .low, .sufficient, .good:
            // Not excellent yet, show preloading state
            if state != .notPreloading {
                state = .preloading
            }
        case .excellent:
            // Buffer is excellent, show green
            state = .preloaded
        }
    }
}