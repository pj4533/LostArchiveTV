//
//  BufferingMonitor.swift
//  LostArchiveTV
//
//  Created by Claude on 2025-06-28.
//

import AVFoundation
import Combine
import Foundation
import OSLog

/// Monitors AVPlayer buffering state and calculates buffer metrics
@MainActor
final class BufferingMonitor: ObservableObject {
    // MARK: - Constants
    
    /// Target buffer duration in seconds for optimal playback
    private static let targetBufferSeconds: Double = 30.0
    
    /// Minimum change in buffer seconds to update fill rate
    private static let minimumBufferChangeThreshold: Double = 0.1
    
    // MARK: - Published Properties
    
    /// Buffer progress as a percentage of the target buffer (0.0 to 1.0)
    @Published private(set) var bufferProgress: Double = 0.0
    
    /// Actual seconds buffered ahead of current playback position
    @Published private(set) var bufferSeconds: Double = 0.0
    
    /// Current buffer state based on available buffer duration
    @Published private(set) var bufferState: BufferState = .unknown
    
    /// Indicates if the player is actively buffering new content
    @Published private(set) var isActivelyBuffering: Bool = false
    
    /// Indicates if playback is likely to continue without interruption
    @Published private(set) var isPlaybackLikelyToKeepUp: Bool = false
    
    /// Rate of buffer fill/drain in seconds per second
    @Published private(set) var bufferFillRate: Double = 0.0
    
    // MARK: - Private Properties
    
    private let logger = Logger.bufferingMonitor
    private var player: AVPlayer?
    private var observations: Set<AnyCancellable> = []
    
    // For tracking buffer fill rate
    private var lastBufferUpdate: Date?
    private var lastBufferSeconds: Double = 0.0
    
    // For stabilization of initial readings
    private var isStabilized: Bool = false
    private var stabilizationReadings: [Double] = []
    private let stabilizationThreshold = 3 // Number of consistent readings needed
    
    // MARK: - Initialization
    
    init() {
        logger.info("📊 BufferingMonitor initialized")
    }
    
    deinit {
        // Cleanup will be handled by the caller
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring the given AVPlayer
    /// - Parameter player: The AVPlayer to monitor
    func startMonitoring(_ player: AVPlayer) {
        logger.info("🚀 startMonitoring called with player: \(String(describing: Unmanaged.passUnretained(player).toOpaque()))")
        
        cleanup()
        self.player = player
        
        logger.info("📊 Starting buffer monitoring for player")
        Logger.preloading.info("🔌 BUFFER MONITOR: Started monitoring player \(String(describing: Unmanaged.passUnretained(player).toOpaque()))")
        
        // Reset stabilization state
        isStabilized = false
        stabilizationReadings.removeAll()
        logger.debug("🔄 Reset stabilization state - isStabilized: false, readings cleared")
        
        setupObservations()
        
        // Log initial player state
        if let currentItem = player.currentItem {
            logger.debug("📱 Initial player state - currentItem: \(currentItem), status: \(currentItem.status.rawValue)")
            logger.debug("📊 Initial buffer state - loadedTimeRanges: \(currentItem.loadedTimeRanges.count) ranges")
        } else {
            logger.warning("⚠️ No current item in player when starting monitoring")
        }
        
        // Perform initial buffer check immediately
        logger.debug("🔍 Performing initial buffer check")
        updateBufferMetrics()
        
        // Schedule additional stabilization checks
        Task {
            logger.debug("⏰ Starting stabilization check sequence")
            
            // Wait a moment for player to settle
            try? await Task.sleep(for: .milliseconds(100))
            logger.debug("⏰ First stabilization check (100ms)")
            updateBufferMetrics()
            
            // Another check after a short delay
            try? await Task.sleep(for: .milliseconds(200))
            logger.debug("⏰ Second stabilization check (300ms total)")
            updateBufferMetrics()
        }
    }
    
    /// Stop monitoring and clean up resources
    func stopMonitoring() {
        logger.info("🛑 stopMonitoring called")
        let playerAddress = player.map { String(describing: Unmanaged.passUnretained($0).toOpaque()) } ?? "nil"
        logger.info("📊 Stopping buffer monitoring for player: \(playerAddress)")
        cleanup()
    }
    
    // MARK: - Private Methods
    
    private func setupObservations() {
        guard let player = player else {
            logger.error("❌ setupObservations called but player is nil")
            return
        }
        
        logger.debug("🔗 Setting up observations for player")
        
        // Observe player item changes
        player.publisher(for: \.currentItem)
            .sink { [weak self] item in
                self?.logger.debug("🔄 Player currentItem publisher fired - item: \(item != nil ? "present" : "nil")")
                self?.handlePlayerItemChange(item)
            }
            .store(in: &observations)
        
        logger.debug("✅ Player currentItem observer set up")
        
        // Start observing current item if available
        if let currentItem = player.currentItem {
            logger.debug("📱 Current item exists, setting up item observations")
            observePlayerItem(currentItem)
        } else {
            logger.debug("⚠️ No current item available yet")
        }
    }
    
    private func handlePlayerItemChange(_ item: AVPlayerItem?) {
        logger.info("🔄 Player item changed - new item: \(item != nil ? "present" : "nil")")
        
        if let item = item {
            logger.debug("📱 New item details - status: \(item.status.rawValue), duration: \(CMTimeGetSeconds(item.duration))")
            logger.debug("📊 New item buffer state - loadedTimeRanges: \(item.loadedTimeRanges.count) ranges")
        }
        
        // Clear previous item observations
        let observationCount = observations.count
        observations.removeAll()
        logger.debug("🧹 Cleared \(observationCount) previous observations")
        
        // Reset buffer metrics
        logger.debug("🔄 Resetting buffer metrics")
        resetMetrics()
        
        // Observe new item
        if let item = item {
            logger.debug("🔗 Setting up observations for new player item")
            observePlayerItem(item)
        } else {
            logger.warning("⚠️ No new item to observe")
        }
    }
    
    private func observePlayerItem(_ item: AVPlayerItem) {
        logger.debug("🔗 observePlayerItem called for item: \(item)")
        
        // Log initial state
        logger.debug("📊 Initial item state:")
        logger.debug("  - loadedTimeRanges: \(item.loadedTimeRanges.count) ranges")
        logger.debug("  - isPlaybackLikelyToKeepUp: \(item.isPlaybackLikelyToKeepUp)")
        logger.debug("  - isPlaybackBufferEmpty: \(item.isPlaybackBufferEmpty)")
        logger.debug("  - isPlaybackBufferFull: \(item.isPlaybackBufferFull)")
        
        // Observe loadedTimeRanges for buffer calculation
        item.publisher(for: \.loadedTimeRanges)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] timeRanges in
                self?.logger.debug("📈 loadedTimeRanges changed - count: \(timeRanges.count)")
                if !timeRanges.isEmpty {
                    for (index, range) in timeRanges.enumerated() {
                        let timeRange = range.timeRangeValue
                        let start = CMTimeGetSeconds(timeRange.start)
                        let duration = CMTimeGetSeconds(timeRange.duration)
                        self?.logger.debug("  Range \(index): start=\(start)s, duration=\(duration)s")
                    }
                }
                self?.updateBufferMetrics()
            }
            .store(in: &observations)
        
        logger.debug("✅ loadedTimeRanges observer set up")
        
        // Observe playbackLikelyToKeepUp
        item.publisher(for: \.isPlaybackLikelyToKeepUp)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLikelyToKeepUp in
                self?.isPlaybackLikelyToKeepUp = isLikelyToKeepUp
                self?.logger.info("🎯 Playback likely to keep up changed: \(isLikelyToKeepUp)")
            }
            .store(in: &observations)
        
        logger.debug("✅ isPlaybackLikelyToKeepUp observer set up")
        
        // Observe playbackBufferEmpty
        item.publisher(for: \.isPlaybackBufferEmpty)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEmpty in
                self?.logger.info("📉 Playback buffer empty changed: \(isEmpty)")
                if isEmpty {
                    self?.logger.warning("⚠️ Playback buffer is now EMPTY")
                    self?.bufferState = .empty
                    self?.bufferSeconds = 0.0
                    self?.bufferProgress = 0.0
                }
            }
            .store(in: &observations)
        
        logger.debug("✅ isPlaybackBufferEmpty observer set up")
        
        // Observe playbackBufferFull
        item.publisher(for: \.isPlaybackBufferFull)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isFull in
                self?.isActivelyBuffering = !isFull
                self?.logger.info("📊 Buffer full changed: \(isFull), actively buffering: \(!isFull)")
            }
            .store(in: &observations)
        
        logger.debug("✅ isPlaybackBufferFull observer set up")
        logger.debug("✅ All observations set up for player item")
    }
    
    private func updateBufferMetrics() {
        logger.debug("📊 updateBufferMetrics called")
        
        guard let player = player,
              let currentItem = player.currentItem else {
            logger.warning("⚠️ Cannot update metrics - player: \(self.player != nil), currentItem: nil")
            resetMetrics()
            return
        }
        
        let currentTime = currentItem.currentTime()
        guard currentTime.isValid && currentTime.isNumeric else {
            logger.warning("⚠️ Current time is not valid - isValid: \(currentTime.isValid), isNumeric: \(currentTime.isNumeric)")
            return
        }
        
        logger.debug("⏱️ Current playback time: \(CMTimeGetSeconds(currentTime))s")
        
        // Calculate available buffer from loaded time ranges
        let availableBuffer = calculateAvailableBuffer(for: currentItem, currentTime: currentTime)
        logger.debug("📏 Calculated available buffer: \(availableBuffer)s")
        
        // Handle stabilization for initial readings
        if !isStabilized {
            logger.debug("🔄 Stabilization in progress - current readings: \(self.stabilizationReadings.count)")
            stabilizationReadings.append(availableBuffer)
            logger.debug("📊 Added reading: \(availableBuffer)s, total readings: \(self.stabilizationReadings)")
            
            // Check if we have enough readings
            if self.stabilizationReadings.count >= self.stabilizationThreshold {
                // Check if readings are consistent (not all zero)
                let nonZeroReadings = stabilizationReadings.filter { $0 > 0 }
                logger.debug("🔍 Checking stabilization - nonZero: \(nonZeroReadings.count), total: \(self.stabilizationReadings.count)")
                
                if nonZeroReadings.count >= 2 || stabilizationReadings.count >= 5 {
                    isStabilized = true
                    logger.info("✅ STABILIZED with \(nonZeroReadings.count) non-zero readings")
                    Logger.preloading.info("✅ BUFFER MONITOR: Stabilized with \(nonZeroReadings.count) non-zero readings")
                }
            }
            
            // If not stabilized and buffer is reported as 0, don't update state yet
            if availableBuffer == 0 && !isStabilized {
                logger.debug("⏳ Waiting for stabilization (reading \(self.stabilizationReadings.count)/\(self.stabilizationThreshold)) - skipping update")
                Logger.preloading.debug("⏳ BUFFER MONITOR: Waiting for stabilization (reading \(self.stabilizationReadings.count)/\(self.stabilizationThreshold))")
                return
            }
        }
        
        // Update buffer seconds
        let previousSeconds = bufferSeconds
        bufferSeconds = availableBuffer
        
        // Calculate buffer progress (capped at 1.0)
        _ = bufferProgress
        bufferProgress = min(availableBuffer / Self.targetBufferSeconds, 1.0)
        
        // Update buffer state
        let previousState = bufferState
        bufferState = BufferState.from(seconds: availableBuffer)
        
        // Log state changes
        if previousState != bufferState {
            logger.info("🔄 Buffer state changed: \(previousState.description) → \(self.bufferState.description)")
        }
        
        // Calculate fill rate
        updateFillRate(currentBuffer: availableBuffer)
        
        logger.info("📊 Buffer updated: \(availableBuffer, format: .fixed(precision: 1))s (\(Int(self.bufferProgress * 100))%), state: \(self.bufferState.description)")
        
        // Log significant changes
        if abs(previousSeconds - bufferSeconds) > 1.0 {
            logger.debug("📈 Significant buffer change: \(previousSeconds)s → \(self.bufferSeconds)s")
        }
        
        // Log to preloading category when buffer reaches excellent
        if self.bufferState == .excellent && previousState != .excellent {
            logger.notice("🎉 Buffer reached EXCELLENT state!")
            Logger.preloading.notice("💚 BUFFER MONITOR: Buffer reached EXCELLENT (\(availableBuffer)s, progress=\(self.bufferProgress))")
        }
    }
    
    private func calculateAvailableBuffer(for item: AVPlayerItem, currentTime: CMTime) -> Double {
        let loadedTimeRanges = item.loadedTimeRanges
        
        logger.debug("🔍 calculateAvailableBuffer - ranges: \(loadedTimeRanges.count), currentTime: \(CMTimeGetSeconds(currentTime))s")
        
        guard !loadedTimeRanges.isEmpty else {
            logger.debug("📊 No loaded time ranges available")
            return 0.0
        }
        
        // Find the time range that contains or is ahead of current time
        for (index, range) in loadedTimeRanges.enumerated() {
            let timeRange = range.timeRangeValue
            let rangeStart = CMTimeGetSeconds(timeRange.start)
            let rangeEnd = CMTimeGetSeconds(CMTimeAdd(timeRange.start, timeRange.duration))
            let current = CMTimeGetSeconds(currentTime)
            
            logger.debug("  Range \(index): [\(rangeStart)s - \(rangeEnd)s], current: \(current)s")
            
            // Check if current time is within this range
            if current >= rangeStart && current <= rangeEnd {
                // Return the amount buffered ahead
                let bufferedAhead = rangeEnd - current
                logger.debug("✅ Found containing range - buffered ahead: \(bufferedAhead)s")
                return bufferedAhead
            }
            
            // Check if this range is ahead of current time
            if rangeStart > current {
                // There's a gap, but we can report the future buffer
                // In practice, we might want to handle gaps differently
                let futureBuffer = rangeEnd - current
                logger.debug("⚠️ Found future range with gap - future buffer: \(futureBuffer)s")
                return futureBuffer
            }
        }
        
        logger.debug("❌ No suitable range found - returning 0")
        return 0.0
    }
    
    private func updateFillRate(currentBuffer: Double) {
        let now = Date()
        
        if let lastUpdate = lastBufferUpdate {
            let timeDelta = now.timeIntervalSince(lastUpdate)
            
            // Only update if enough time has passed
            if timeDelta >= 0.5 {
                let bufferDelta = currentBuffer - lastBufferSeconds
                
                // Only update if there's meaningful change
                if abs(bufferDelta) >= Self.minimumBufferChangeThreshold {
                    bufferFillRate = bufferDelta / timeDelta
                    logger.info("📈 Buffer fill rate: \(self.bufferFillRate, format: .fixed(precision: 2)) seconds/second (delta: \(bufferDelta)s over \(timeDelta)s)")
                } else {
                    logger.debug("📊 Buffer change too small to update fill rate: \(bufferDelta)s")
                }
                
                lastBufferUpdate = now
                lastBufferSeconds = currentBuffer
            } else {
                logger.debug("⏱️ Not enough time elapsed for fill rate update: \(timeDelta)s")
            }
        } else {
            // First update
            logger.debug("📊 First fill rate update - initializing baseline")
            lastBufferUpdate = now
            lastBufferSeconds = currentBuffer
        }
    }
    
    private func resetMetrics() {
        logger.debug("🔄 Resetting all buffer metrics")
        
        bufferProgress = 0.0
        bufferSeconds = 0.0
        bufferState = .unknown
        isActivelyBuffering = false
        isPlaybackLikelyToKeepUp = false
        bufferFillRate = 0.0
        lastBufferUpdate = nil
        lastBufferSeconds = 0.0
        isStabilized = false
        stabilizationReadings.removeAll()
        
        logger.debug("✅ Buffer metrics reset complete")
    }
    
    private func cleanup() {
        logger.debug("🧹 Starting cleanup")
        
        let observationCount = observations.count
        observations.forEach { $0.cancel() }
        observations.removeAll()
        logger.debug("🗑️ Cancelled and removed \(observationCount) observations")
        
        player = nil
        logger.debug("🔌 Player reference cleared")
        
        resetMetrics()
        
        logger.info("✅ Cleanup complete")
    }
}