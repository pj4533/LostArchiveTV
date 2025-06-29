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
                Logger.preloading.notice("📨 NOTIFICATION RECEIVED: PreloadingIndicatorManager received \(status == .started ? "started" : "completed") signal")
                switch status {
                case .started:
                    Logger.preloading.info("📍 PRELOAD: VideoCacheService signaled preloading started")
                    // Default to next direction - the actual preloading code should have already set this
                    self?.setPreloading(direction: .next)
                    // Start monitoring immediately - now using single source of truth
                    self?.startBufferStateMonitoring()
                case .completed:
                    // Keep monitoring even after preload completes
                    Logger.preloading.info("📍 PRELOAD: VideoCacheService signaled preloading completed")
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
        // Single source of truth: Only check BufferingMonitor for buffer state
        // This fixes issue #86 where multiple sources caused inconsistent UI
        
        // Check if the preloaded video has reached a ready buffer state
        guard let viewModel = SharedViewModelProvider.shared.videoPlayerViewModel else {
            Logger.preloading.warning("⚠️ PRELOAD: No videoPlayerViewModel available for buffer checking")
            return
        }
        
        // Get current player address for comparison
        let currentPlayerAddress = viewModel.player.map { String(describing: Unmanaged.passUnretained($0).toOpaque()) } ?? "nil"
        
        // Only check the buffering monitor - single source of truth
        let monitor = preloadingDirection == .next 
            ? viewModel.nextBufferingMonitor 
            : viewModel.previousBufferingMonitor
        
        Logger.preloading.debug("🔍 PRELOAD CHECK: Direction=\(self.preloadingDirection == .next ? "next" : "prev"), Monitor exists=\(monitor != nil), Current player=\(currentPlayerAddress)")
        
        if let monitor = monitor {
            // Log which player the monitor is tracking
            let monitoredPlayer = preloadingDirection == .next
                ? viewModel.transitionManager?.nextPlayer
                : viewModel.transitionManager?.prevPlayer
            let monitoredPlayerAddress = monitoredPlayer.map { String(describing: Unmanaged.passUnretained($0).toOpaque()) } ?? "nil"
            
            Logger.preloading.debug("📊 PRELOAD MONITOR: State=\(monitor.bufferState.rawValue), Seconds=\(monitor.bufferSeconds), Progress=\(monitor.bufferProgress), Monitoring player=\(monitoredPlayerAddress)")
            
            // Update current buffer state
            currentBufferState = monitor.bufferState
            
            // Check if BufferingMonitor indicates excellent buffer
            if state == .preloading && monitor.bufferState == .excellent {
                Logger.preloading.notice("✅ PRELOAD READY: Buffer reached excellent (monitor: \(monitor.bufferState.description)), showing green")
                setPreloaded()
                stopBufferStateMonitoring()
                return
            }
            
            if state == .preloading {
                Logger.preloading.debug("⏳ PRELOAD WAITING: Buffer not excellent yet: \(monitor.bufferState.description)")
            }
        } else {
            // No monitor available yet
            currentBufferState = .unknown
            Logger.preloading.debug("⏳ PRELOAD WAITING: No monitor available yet for \(self.preloadingDirection == .next ? "next" : "prev") direction")
        }
    }

    func setPreloading(direction: PreloadDirection = .next) {
        // Only switch to preloading if we're not already in preloaded state
        if state != .preloaded {
            preloadingDirection = direction
            state = .preloading
            currentBufferState = .unknown
            Logger.preloading.info("🔄 PRELOAD START: Direction=\(direction == .next ? "next" : "previous"), State changed to preloading")
        } else {
            Logger.preloading.warning("⚠️ PRELOAD IGNORED: Already in preloaded state, ignoring new preload signal")
        }
    }

    func setPreloaded() {
        state = .preloaded
        Logger.preloading.notice("🟢 PRELOAD COMPLETE: State changed to preloaded (green)")
    }

    func reset() {
        // Never go back to notPreloading - always stay in preloading state
        state = .preloading
        currentBufferState = .unknown
        // Don't stop monitoring - keep checking buffer state
        Logger.preloading.info("🔄 PRELOAD RESET: State changed to preloading (never goes black)")
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