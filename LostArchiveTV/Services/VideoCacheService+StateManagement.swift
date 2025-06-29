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
    // Method to signal that the first video is ready and playing
    func setFirstVideoReady() {
        Logger.caching.info("VideoCacheService: First video is now playing, enabling background caching")
        isFirstVideoReady = true
        Logger.caching.info("VideoCacheService: isFirstVideoReady set to \(self.isFirstVideoReady)")
    }

    // Method to signal that preloading is complete and caching can proceed
    func setPreloadingComplete() {
        Logger.caching.info("✅ PRIORITY: Preloading complete, removing hard block on caching operations")

        // Remove the hard block first
        isPreloadingInProgress = false
        Logger.caching.info("✅ PRIORITY: isPreloadingInProgress = false - caching operations allowed again")

        // Then set the completion flag
        isPreloadingComplete = true
        Logger.caching.info("✅ PRIORITY: isPreloadingComplete set to \(self.isPreloadingComplete), cache tasks can now resume")

        // Add a retry task to ensure caching gets a chance to restart even if no one calls ensureVideosAreCached
        Task {
            try? await Task.sleep(for: .seconds(1.0))

            // If we still don't have an active caching task running after 1 second,
            // we'll not only log, but also check if we need to restart the cache
            if cacheTask == nil || cacheTask?.isCancelled == true {
                Logger.caching.warning("⚠️ RECOVERY CHECK: 1 second after setPreloadingComplete, still no active cache task")
                Logger.caching.warning("⚠️ RECOVERY CHECK: isPreloadingInProgress=\(self.isPreloadingInProgress), isPreloadingComplete=\(self.isPreloadingComplete)")

                // We don't have access to cacheManager here, so we can't check cache levels directly.
                // Instead, we'll only trigger recovery if we've detected a truly stalled system

                // Only restart if the first video is ready and preloading has completed
                if self.isFirstVideoReady {
                    Logger.caching.warning("🔄 RECOVERY: Detected stalled cache system, initiating recovery notification")

                    // Post a notification to trigger a cache restart
                    // Note: The BaseVideoViewModel will handle checking if the cache actually needs filling
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: NSNotification.Name("CacheSystemNeedsRestart"), object: nil)
                    }

                    Logger.caching.warning("🔔 RECOVERY: Posted CacheSystemNeedsRestart notification")
                } else {
                    // First video isn't ready yet, so skip restart
                    Logger.caching.info("✅ SKIP RECOVERY: First video not ready yet, no need to restart caching")
                }
            }
        }
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