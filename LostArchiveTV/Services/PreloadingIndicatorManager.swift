import SwiftUI
import Combine

@MainActor
class PreloadingIndicatorManager: ObservableObject {
    static let shared = PreloadingIndicatorManager()

    @Published var state: PreloadingState = .notPreloading

    internal var cancellables = Set<AnyCancellable>()

    private init() {
        // Setup both observers: direct PreloadService and CacheStatusChanged
        setupPreloadObservers()
        setupCacheStatusObserver()
    }

    private func setupPreloadObservers() {
        // Listen for preloading status changes using Combine
        VideoCacheService.preloadingStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                switch status {
                case .started:
                    self?.setPreloading()
                case .completed:
                    // When a preload completes, check if we should advance to "preloaded" state
                    // This happens if TransitionManager.nextVideoReady is true
                    self?.updateStateFromTransitionManager()
                }
            }
            .store(in: &cancellables)
    }

    func setPreloading() {
        // Only switch to preloading if we're not already in preloaded state
        if state != .preloaded {
            state = .preloading
        }
    }

    func setPreloaded() {
        state = .preloaded
    }

    func reset() {
        state = .notPreloading
    }
}

// MARK: - Test Helpers
extension PreloadingIndicatorManager {
    /// Reset subscriptions for testing
    func resetForTesting() {
        cancellables.removeAll()
        state = .notPreloading
        setupPreloadObservers()
        setupCacheStatusObserver()
    }
}