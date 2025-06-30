//
//  VideoCacheService+StateManagement.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 5/31/25.
//

import Foundation
import OSLog

// MARK: - State Management
extension VideoCacheService {
    // Method to signal that preloading is complete and caching can proceed
    func setPreloadingComplete() {
        Logger.caching.info("✅ PRIORITY: Preloading complete, removing hard block on caching operations")

        // Remove the hard block first
        isPreloadingInProgress = false
        Logger.caching.info("✅ PRIORITY: isPreloadingInProgress = false - caching operations allowed again")

        // Then set the completion flag
        isPreloadingComplete = true
        Logger.caching.info("✅ PRIORITY: isPreloadingComplete set to \(self.isPreloadingComplete), cache tasks can now resume")

        // Removed aggressive recovery mechanism that was causing duplicate video loads.
        // The system already has proper mechanisms to start caching when needed through ensureVideosAreCached.
        // The arbitrary 1-second timeout was creating false positives and race conditions.
    }

    // Method to signal that preloading has started and caching should wait
    func setPreloadingStarted() {
        Logger.caching.info("⚠️ PRIORITY: Preloading started, activating hard block on ALL caching operations")
        Logger.preloading.notice("🚨 SIGNAL CHECK: setPreloadingStarted() called - should this trigger PreloadingIndicatorManager?")

        // Set the hard block flag first
        isPreloadingInProgress = true
        Logger.caching.info("⚠️ PRIORITY: isPreloadingInProgress = true - ALL caching is now blocked")

        // Cancel any active cache tasks to free up resources for preloading
        if let task = cacheTask, !task.isCancelled {
            Logger.caching.info("⚠️ PRIORITY: Actively canceling running cache task to prioritize preloading")
            task.cancel()
            cacheTask = nil
        } else {
            Logger.caching.info("⚠️ PRIORITY: No active cache task to cancel")
        }

        // Update the completion flag to prevent new caching tasks from starting
        isPreloadingComplete = false
        Logger.caching.info("⚠️ PRIORITY: isPreloadingComplete set to \(self.isPreloadingComplete)")
        
        // NOTE: We do NOT send a preloading notification here because this is just
        // blocking cache operations during a transition. The actual preloading
        // notification should only be sent when we start preloading NEW videos.
        Logger.preloading.notice("🚫 SIGNAL: NOT sending preloading notification from setPreloadingStarted() - this is just a cache block")
    }
    
    func cancelCaching() {
        if let task = cacheTask, !task.isCancelled {
            Logger.caching.info("🛑 CANCELLATION: Explicitly cancelling caching task")
            task.cancel()
            cacheTask = nil
        } else {
            Logger.caching.info("ℹ️ CANCELLATION: No active cache task to cancel")
        }
    }

    /// Pauses the caching process during trim mode
    func pauseCaching() {
        Logger.caching.info("⏸️ PAUSE: Pausing caching for trim mode")
        if let task = cacheTask, !task.isCancelled {
            Logger.caching.info("⏸️ PAUSE: Actively cancelling running cache task")
            task.cancel()
            cacheTask = nil
        } else {
            Logger.caching.info("⏸️ PAUSE: No active cache task to cancel")
        }
    }

    /// Resumes the caching process after trim mode ends
    func resumeCaching() {
        Logger.caching.info("▶️ RESUME: Resuming caching after trim mode")
        // Also reset the preloading state to ensure caching can proceed
        isPreloadingInProgress = false
        isPreloadingComplete = true
        Logger.caching.info("▶️ RESUME: Reset preloading flags: isPreloadingInProgress=\(self.isPreloadingInProgress), isPreloadingComplete=\(self.isPreloadingComplete)")
        // The next call to ensureVideosAreCached will restart caching
    }
}