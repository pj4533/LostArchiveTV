//
//  BufferingMonitor+Metrics.swift
//  LostArchiveTV
//
//  Created by Claude on 2025-06-28.
//

import AVFoundation
import Foundation
import OSLog

extension BufferingMonitor {
    // MARK: - Buffer Metrics
    
    func updateBufferMetrics() {
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
    
    func resetMetrics() {
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
}