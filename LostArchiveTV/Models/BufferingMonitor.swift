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
    
    private let logger = Logger(subsystem: "com.pj4533.LostArchiveTV", category: "BufferingMonitor")
    private var player: AVPlayer?
    private var observations: Set<AnyCancellable> = []
    
    // For tracking buffer fill rate
    private var lastBufferUpdate: Date?
    private var lastBufferSeconds: Double = 0.0
    
    // MARK: - Initialization
    
    init() {
        logger.debug("BufferingMonitor initialized")
    }
    
    deinit {
        Task { @MainActor in
            cleanup()
        }
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring the given AVPlayer
    /// - Parameter player: The AVPlayer to monitor
    func startMonitoring(_ player: AVPlayer) {
        cleanup()
        self.player = player
        
        logger.info("Starting buffer monitoring for player")
        Logger.preloading.info("🔌 BUFFER MONITOR: Started monitoring player \(player)")
        
        setupObservations()
        updateBufferMetrics()
    }
    
    /// Stop monitoring and clean up resources
    func stopMonitoring() {
        logger.info("Stopping buffer monitoring")
        cleanup()
    }
    
    // MARK: - Private Methods
    
    private func setupObservations() {
        guard let player = player else { return }
        
        // Observe player item changes
        player.publisher(for: \.currentItem)
            .sink { [weak self] item in
                self?.handlePlayerItemChange(item)
            }
            .store(in: &observations)
        
        // Start observing current item if available
        if let currentItem = player.currentItem {
            observePlayerItem(currentItem)
        }
    }
    
    private func handlePlayerItemChange(_ item: AVPlayerItem?) {
        logger.debug("Player item changed")
        
        // Clear previous item observations
        observations.removeAll()
        
        // Reset buffer metrics
        resetMetrics()
        
        // Observe new item
        if let item = item {
            observePlayerItem(item)
        }
    }
    
    private func observePlayerItem(_ item: AVPlayerItem) {
        // Observe loadedTimeRanges for buffer calculation
        item.publisher(for: \.loadedTimeRanges)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateBufferMetrics()
            }
            .store(in: &observations)
        
        // Observe playbackLikelyToKeepUp
        item.publisher(for: \.isPlaybackLikelyToKeepUp)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLikelyToKeepUp in
                self?.isPlaybackLikelyToKeepUp = isLikelyToKeepUp
                self?.logger.debug("Playback likely to keep up: \(isLikelyToKeepUp)")
            }
            .store(in: &observations)
        
        // Observe playbackBufferEmpty
        item.publisher(for: \.isPlaybackBufferEmpty)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEmpty in
                if isEmpty {
                    self?.logger.warning("Playback buffer is empty")
                    self?.bufferState = .empty
                    self?.bufferSeconds = 0.0
                    self?.bufferProgress = 0.0
                }
            }
            .store(in: &observations)
        
        // Observe playbackBufferFull
        item.publisher(for: \.isPlaybackBufferFull)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isFull in
                self?.isActivelyBuffering = !isFull
                self?.logger.debug("Buffer full: \(isFull), actively buffering: \(!isFull)")
            }
            .store(in: &observations)
    }
    
    private func updateBufferMetrics() {
        guard let player = player,
              let currentItem = player.currentItem else {
            resetMetrics()
            return
        }
        
        let currentTime = currentItem.currentTime()
        guard currentTime.isValid && currentTime.isNumeric else {
            logger.debug("Current time is not valid")
            return
        }
        
        // Calculate available buffer from loaded time ranges
        let availableBuffer = calculateAvailableBuffer(for: currentItem, currentTime: currentTime)
        
        // Update buffer seconds
        bufferSeconds = availableBuffer
        
        // Calculate buffer progress (capped at 1.0)
        bufferProgress = min(availableBuffer / Self.targetBufferSeconds, 1.0)
        
        // Update buffer state
        bufferState = BufferState.from(seconds: availableBuffer)
        
        // Calculate fill rate
        updateFillRate(currentBuffer: availableBuffer)
        
        logger.debug("Buffer updated: \(availableBuffer, format: .fixed(precision: 1))s (\(Int(self.bufferProgress * 100))%), state: \(self.bufferState.description)")
        
        // Log to preloading category when buffer reaches excellent
        if self.bufferState == .excellent {
            Logger.preloading.notice("💚 BUFFER MONITOR: Buffer reached EXCELLENT (\(availableBuffer)s, progress=\(self.bufferProgress))")
        }
    }
    
    private func calculateAvailableBuffer(for item: AVPlayerItem, currentTime: CMTime) -> Double {
        let loadedTimeRanges = item.loadedTimeRanges
        
        guard !loadedTimeRanges.isEmpty else {
            return 0.0
        }
        
        // Find the time range that contains or is ahead of current time
        for range in loadedTimeRanges {
            let timeRange = range.timeRangeValue
            let rangeStart = CMTimeGetSeconds(timeRange.start)
            let rangeEnd = CMTimeGetSeconds(CMTimeAdd(timeRange.start, timeRange.duration))
            let current = CMTimeGetSeconds(currentTime)
            
            // Check if current time is within this range
            if current >= rangeStart && current <= rangeEnd {
                // Return the amount buffered ahead
                return rangeEnd - current
            }
            
            // Check if this range is ahead of current time
            if rangeStart > current {
                // There's a gap, but we can report the future buffer
                // In practice, we might want to handle gaps differently
                return rangeEnd - current
            }
        }
        
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
                    logger.debug("Buffer fill rate: \(self.bufferFillRate, format: .fixed(precision: 2)) seconds/second")
                }
                
                lastBufferUpdate = now
                lastBufferSeconds = currentBuffer
            }
        } else {
            // First update
            lastBufferUpdate = now
            lastBufferSeconds = currentBuffer
        }
    }
    
    private func resetMetrics() {
        bufferProgress = 0.0
        bufferSeconds = 0.0
        bufferState = .unknown
        isActivelyBuffering = false
        isPlaybackLikelyToKeepUp = false
        bufferFillRate = 0.0
        lastBufferUpdate = nil
        lastBufferSeconds = 0.0
    }
    
    private func cleanup() {
        observations.forEach { $0.cancel() }
        observations.removeAll()
        player = nil
        resetMetrics()
    }
}