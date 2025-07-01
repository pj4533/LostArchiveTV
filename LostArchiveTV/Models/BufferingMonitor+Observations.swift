//
//  BufferingMonitor+Observations.swift
//  LostArchiveTV
//
//  Created by Claude on 2025-06-28.
//

import AVFoundation
import Combine
import Foundation
import OSLog

extension BufferingMonitor {
    // MARK: - Observation Setup
    
    func setupObservations() {
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
    
    func handlePlayerItemChange(_ item: AVPlayerItem?) {
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
    
    func observePlayerItem(_ item: AVPlayerItem) {
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
    
    func cleanup() {
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