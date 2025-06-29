import Foundation
import SwiftUI
import Combine
import OSLog

@MainActor
class PreloadingIndicatorManager: ObservableObject {
    static let shared = PreloadingIndicatorManager()

    @Published var state: PreloadingState = .notPreloading
    @Published var currentBufferState: BufferState = .unknown

    internal var cancellables: Set<AnyCancellable> = Set<AnyCancellable>()
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
        
        // ALSO listen to the actual buffer state updates from TransitionPreloadManager
        // TODO: Fix type inference issue with TransitionPreloadManager.bufferStatusPublisher
        /*
        TransitionPreloadManager.bufferStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] bufferState in
                    guard let self = self else { return }
                    
                    // Update current buffer state
                    self.currentBufferState = bufferState
                    
                    // For combined buffer states, check if ANY direction has excellent buffer
                    // The combined state might be worse due to the other direction being unknown
                    if self.state == .preloading {
                        // Check the actual individual buffer states from the transition manager
                        if let viewModel = SharedViewModelProvider.shared.videoPlayerViewModel,
                           let transitionManager = viewModel.transitionManager {
                            let nextBuffer = transitionManager.nextBufferState
                            let prevBuffer = transitionManager.prevBufferState
                            
                            if nextBuffer == .excellent || prevBuffer == .excellent {
                                self.logger.info("🎯 Buffer reached excellent (next: \(nextBuffer), prev: \(prevBuffer)), showing green")
                                self.setPreloaded()
                                self.stopBufferStateMonitoring()
                            }
                        }
                    }
                }
            )
            .store(in: &cancellables)
        */
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
        
        // Check both the buffering monitor and transition manager buffer states
        let monitor = preloadingDirection == .next 
            ? viewModel.nextBufferingMonitor 
            : viewModel.previousBufferingMonitor
        
        // Also check transition manager buffer states
        if let transitionManager = viewModel.transitionManager {
            let nextBuffer = transitionManager.nextBufferState
            let prevBuffer = transitionManager.prevBufferState
            
            // Use the better of the two buffer states for our direction
            let transitionBufferState = preloadingDirection == .next ? nextBuffer : prevBuffer
            
            // Check if either source indicates excellent buffer
            if state == .preloading && (transitionBufferState == .excellent || monitor?.bufferState == .excellent) {
                logger.info("🎯 Buffer reached excellent (transition: \(transitionBufferState.description), monitor: \(monitor?.bufferState.description ?? "nil")), showing green")
                currentBufferState = .excellent
                setPreloaded()
                stopBufferStateMonitoring()
                return
            }
        }
        
        if let bufferState = monitor?.bufferState {
            currentBufferState = bufferState
            
            if state == .preloading {
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
        // Never go back to notPreloading - always stay in preloading state
        state = .preloading
        currentBufferState = .unknown
        // Don't stop monitoring - keep checking buffer state
        logger.info("🔄 Reset preloading indicator to loading state")
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