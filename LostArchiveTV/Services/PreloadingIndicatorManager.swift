import SwiftUI
import Combine
import OSLog

@MainActor
class PreloadingIndicatorManager: ObservableObject {
    static let shared = PreloadingIndicatorManager()

    @Published var state: PreloadingState = .notPreloading
    @Published var currentBufferState: BufferState = .unknown

    internal var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.pj4533.LostArchiveTV", category: "PreloadingIndicatorManager")
    
    // Track which direction we're preloading
    private var preloadingDirection: PreloadDirection = .next
    
    // Timer for periodic buffer state checks
    private var bufferCheckTimer: Timer?
    
    private init() {
        // Setup observers
        setupPreloadObservers()
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
                    // When a preload completes, start monitoring buffer state
                    self?.startBufferStateMonitoring()
                }
            }
            .store(in: &cancellables)
    }
    
    private func startBufferStateMonitoring() {
        // Stop any existing timer
        bufferCheckTimer?.invalidate()
        
        // Start a timer to periodically check buffer state
        bufferCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPreloadedBufferState()
            }
        }
        
        // Do an immediate check
        checkPreloadedBufferState()
    }
    
    private func stopBufferStateMonitoring() {
        bufferCheckTimer?.invalidate()
        bufferCheckTimer = nil
    }
    
    private func checkPreloadedBufferState() {
        // Check if the preloaded video has reached a ready buffer state
        guard let viewModel = SharedViewModelProvider.shared.videoPlayerViewModel else { return }
        
        let monitor = preloadingDirection == .next 
            ? viewModel.nextBufferingMonitor 
            : viewModel.previousBufferingMonitor
        
        if let bufferState = monitor?.bufferState {
            currentBufferState = bufferState
            
            // Only set preloaded when buffer is excellent
            if state == .preloading && bufferState == .excellent {
                logger.info("🎯 Preloaded video buffer is excellent, showing green")
                setPreloaded()
                stopBufferStateMonitoring()
            } else if state == .preloading {
                logger.debug("⏳ Preloading buffer state: \(bufferState.description)")
            }
        }
    }

    func setPreloading(direction: PreloadDirection = .next) {
        // Only switch to preloading if we're not already in preloaded state
        if state != .preloaded {
            preloadingDirection = direction
            state = .preloading
            currentBufferState = .unknown
            logger.info("🔄 Started preloading in direction: \(direction == .next ? "next" : "previous")")
        }
    }

    func setPreloaded() {
        state = .preloaded
        logger.info("✨ Transitioned to preloaded state")
    }

    func reset() {
        state = .notPreloading
        currentBufferState = .unknown
        stopBufferStateMonitoring()
        logger.info("🔄 Reset preloading indicator state")
    }
}

// MARK: - Supporting Types
extension PreloadingIndicatorManager {
    enum PreloadDirection {
        case next
        case previous
    }
}

// MARK: - Test Helpers
extension PreloadingIndicatorManager {
    /// Reset subscriptions for testing
    func resetForTesting() {
        cancellables.removeAll()
        state = .notPreloading
        currentBufferState = .unknown
        stopBufferStateMonitoring()
        setupPreloadObservers()
    }
}