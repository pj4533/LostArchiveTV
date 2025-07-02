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
    
    
    // Buffer state subscription
    private var bufferStateSubscription: AnyCancellable?
    
    // Current active provider being monitored
    private weak var currentProvider: BaseVideoViewModel?
    
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
                    self?.setPreloading()
                    // Setup buffer state subscription
                    self?.setupBufferStateSubscription()
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
    
    private func setupBufferStateSubscription() {
        // Cancel any existing subscription
        bufferStateSubscription?.cancel()
        
        // Get the next buffer monitor publisher from the current provider
        let monitorPublisher: AnyPublisher<BufferingMonitor?, Never>?
        if let provider = currentProvider ?? SharedViewModelProvider.shared.videoPlayerViewModel {
            monitorPublisher = provider.$nextBufferingMonitor.eraseToAnyPublisher()
        } else {
            monitorPublisher = nil
        }
        
        // Use switchToLatest to properly handle monitor instance changes
        // This ensures that when the monitor instance changes:
        // 1. The previous buffer state subscription is automatically cancelled
        // 2. A new subscription is created for the new monitor
        // 3. We don't have memory leaks from old subscriptions
        bufferStateSubscription = monitorPublisher?
            .map { monitor -> AnyPublisher<(BufferingMonitor, BufferState), Never> in
                guard let monitor = monitor else {
                    Logger.preloading.debug("🔄 MONITOR: Monitor became nil, returning empty publisher")
                    return Empty().eraseToAnyPublisher()
                }
                
                Logger.preloading.info("🔌 MONITOR: Switching to new BufferingMonitor instance")
                
                // Return a publisher that emits the monitor along with its buffer state
                return monitor.$bufferState
                    .map { bufferState in (monitor, bufferState) }
                    .eraseToAnyPublisher()
            }
            .switchToLatest() // This is the key operator that handles monitor changes
            .removeDuplicates { $0.1 == $1.1 } // Only emit when buffer state actually changes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (monitor, bufferState) in
                guard let self = self else { return }
                
                // Update current buffer state
                self.currentBufferState = bufferState
                
                Logger.preloading.debug("📊 BUFFER STATE UPDATE: State=\(bufferState.rawValue), Seconds=\(monitor.bufferSeconds), Progress=\(monitor.bufferProgress)")
                
                // Check if buffer is ready and we're still in preloading state
                if self.state == .preloading && bufferState.isReady {
                    Logger.preloading.notice("✅ BUFFER READY via subscription: Buffer is ready (\(bufferState.description)), showing green")
                    self.setPreloaded()
                    // Cancel the subscription as we're done
                    self.bufferStateSubscription?.cancel()
                    self.bufferStateSubscription = nil
                }
            }
        
        if bufferStateSubscription != nil {
            Logger.preloading.info("🔌 BUFFER SUBSCRIPTION: Set up buffer state monitoring for next video")
        } else {
            Logger.preloading.warning("⚠️ BUFFER SUBSCRIPTION: Failed to set up - no video player view model available")
        }
    }
    
    
    private func checkPreloadedBufferState() {
        // Single source of truth: Only check BufferingMonitor for buffer state
        // This fixes issue #86 where multiple sources caused inconsistent UI
        
        // Check if the preloaded video has reached a ready buffer state
        guard let viewModel = currentProvider ?? SharedViewModelProvider.shared.videoPlayerViewModel else {
            Logger.preloading.warning("⚠️ PRELOAD: No video provider available for buffer checking")
            return
        }
        
        // Get current player address for comparison
        let currentPlayerAddress = viewModel.player.map { String(describing: Unmanaged.passUnretained($0).toOpaque()) } ?? "nil"
        
        // Check the next buffering monitor - single source of truth
        let monitor = viewModel.nextBufferingMonitor
        
        Logger.preloading.debug("🔍 PRELOAD CHECK: Monitor exists=\(monitor != nil), Current player=\(currentPlayerAddress)")
        
        if let monitor = monitor {
            // Log which player the monitor is tracking
            var monitoredPlayerAddress = "nil"
            if let videoProvider = viewModel as? VideoProvider,
               let transitionManager = videoProvider.transitionManager,
               let nextPlayer = transitionManager.nextPlayer {
                monitoredPlayerAddress = String(describing: Unmanaged.passUnretained(nextPlayer).toOpaque())
            }
            
            Logger.preloading.debug("📊 PRELOAD MONITOR: State=\(monitor.bufferState.rawValue), Seconds=\(monitor.bufferSeconds), Progress=\(monitor.bufferProgress), Monitoring player=\(monitoredPlayerAddress)")
            
            // Update current buffer state
            currentBufferState = monitor.bufferState
            
            // Check if BufferingMonitor indicates ready buffer
            if state == .preloading && monitor.bufferState.isReady {
                Logger.preloading.notice("✅ PRELOAD READY: Buffer is ready (monitor: \(monitor.bufferState.description)), showing green")
                setPreloaded()
                return
            }
            
            if state == .preloading {
                Logger.preloading.debug("⏳ PRELOAD WAITING: Buffer not excellent yet: \(monitor.bufferState.description)")
            }
        } else {
            // No monitor available yet
            currentBufferState = .unknown
            Logger.preloading.debug("⏳ PRELOAD WAITING: No monitor available yet for next video")
        }
    }

    func setPreloading() {
        // Only switch to preloading if we're not already in preloaded state
        if state != .preloaded {
            state = .preloading
            currentBufferState = .unknown
            Logger.preloading.info("🔄 PRELOAD START: State changed to preloading")
            
            // Setup buffer state subscription
            setupBufferStateSubscription()
        } else {
            Logger.preloading.warning("⚠️ PRELOAD IGNORED: Already in preloaded state, ignoring new preload signal")
        }
    }

    func setPreloaded() {
        state = .preloaded
        Logger.preloading.notice("🟢 PRELOAD COMPLETE: State changed to preloaded (green)")
        // Cancel the subscription when transitioning away from preloading state
        bufferStateSubscription?.cancel()
        bufferStateSubscription = nil
    }

    func reset() {
        // Cancel buffer state subscription when resetting
        bufferStateSubscription?.cancel()
        bufferStateSubscription = nil
        
        // Never go back to notPreloading - always stay in preloading state
        state = .preloading
        currentBufferState = .unknown
        // Don't stop monitoring - keep checking buffer state
        Logger.preloading.info("🔄 PRELOAD RESET: State changed to preloading (never goes black)")
    }
    
    // MARK: - Dynamic Provider Registration
    
    /// Register a video provider to be monitored by the preloading indicator
    /// - Parameter provider: The video provider to monitor
    func registerActiveProvider(_ provider: BaseVideoViewModel) {
        Logger.preloading.notice("🔌 REGISTER: Registering new active provider: \(String(describing: type(of: provider)))")
        
        // Cancel existing subscription if switching providers
        if currentProvider !== provider {
            bufferStateSubscription?.cancel()
            bufferStateSubscription = nil
        }
        
        // Set the new provider
        currentProvider = provider
        
        // Reset state and setup new subscription
        reset()
        setupBufferStateSubscription()
    }
    
    /// Unregister the current provider (typically when dismissing a modal player)
    func unregisterProvider() {
        Logger.preloading.info("🔌 UNREGISTER: Unregistering current provider")
        
        // Cancel subscription
        bufferStateSubscription?.cancel()
        bufferStateSubscription = nil
        
        // Clear the current provider
        currentProvider = nil
        
        // Reset state
        state = .notPreloading
        currentBufferState = .unknown
    }
}

// MARK: - Test Helpers
extension PreloadingIndicatorManager {
    /// Reset subscriptions for testing
    func resetForTesting() {
        cancellables.removeAll()
        bufferStateSubscription?.cancel()
        bufferStateSubscription = nil
        state = .notPreloading
        currentBufferState = .unknown
        setupPreloadObservers()
    }
}