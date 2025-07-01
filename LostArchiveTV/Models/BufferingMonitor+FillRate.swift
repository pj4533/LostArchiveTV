//
//  BufferingMonitor+FillRate.swift
//  LostArchiveTV
//
//  Created by Claude on 2025-06-28.
//

import Foundation
import OSLog

extension BufferingMonitor {
    // MARK: - Fill Rate Calculation
    
    func updateFillRate(currentBuffer: Double) {
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
}