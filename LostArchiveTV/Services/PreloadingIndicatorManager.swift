import SwiftUI
import Combine

@MainActor
class PreloadingIndicatorManager: ObservableObject {
    static let shared = PreloadingIndicatorManager()

    @Published var state: PreloadingState = .notPreloading

    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Setup both observers: direct PreloadService and CacheStatusChanged
        setupPreloadObservers()
        setupCacheStatusObserver()
    }

    private func setupPreloadObservers() {
        // Listen for preloading status changes from PreloadService
        NotificationCenter.default
            .publisher(for: .preloadingStarted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.setPreloading()
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: .preloadingCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // When a preload completes, check if we should advance to "preloaded" state
                // This happens if TransitionManager.nextVideoReady is true
                self?.updateStateFromTransitionManager()
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

// Extend Notification.Name with custom notifications
extension Notification.Name {
    static let preloadingStarted = Notification.Name("preloadingStarted")
    static let preloadingCompleted = Notification.Name("preloadingCompleted")
}