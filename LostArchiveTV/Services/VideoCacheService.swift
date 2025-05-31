//
//  VideoCacheService.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import Foundation
import AVFoundation
import OSLog

actor VideoCacheService {
    internal var cacheTask: Task<Void, Never>?

    // Track whether the first video is ready for playback
    internal var isFirstVideoReady = false

    // Track whether preloading has completed for the current transition
    // Initialize to true to allow initial caching to proceed without waiting for preloading
    internal var isPreloadingComplete = true

    // Flag to completely block ALL caching operations when preloading is in progress
    internal var isPreloadingInProgress = false
    
    func ensureVideosAreCached(cacheManager: VideoCacheManager, archiveService: ArchiveService, identifiers: [ArchiveIdentifier]) async {
        // Log start of process with timestamp to track operations better
        let startTime = CFAbsoluteTimeGetCurrent()
        Logger.caching.info("⏱️ START: ensureVideosAreCached called at \(startTime)")
        // CRITICAL: Check hard block flag first - immediately bail out if preloading is in progress
        if isPreloadingInProgress {
            Logger.caching.info("🛑 HARD BLOCK: ensureVideosAreCached called while preloading is in progress - aborting immediately")

            // Safeguard: If we've been in preloading state for too long (3 seconds), assume something went wrong
            // and reset the state to prevent permanent blocking
            Task {
                // Wait 3 seconds to see if preloading finishes naturally
                try? await Task.sleep(for: .seconds(3.0))

                // If we're still in preloading state after the timeout, force a reset
                if self.isPreloadingInProgress {
                    Logger.caching.warning("⚠️ SAFEGUARD: Preloading state has been active for too long, force resetting state")
                    self.isPreloadingInProgress = false
                    self.isPreloadingComplete = true
                    Logger.caching.warning("⚠️ SAFEGUARD: Flags reset - isPreloadingInProgress: \(self.isPreloadingInProgress), isPreloadingComplete: \(self.isPreloadingComplete)")

                    // Also try to restart caching directly since we had to force reset
                    Task {
                        try? await Task.sleep(for: .seconds(0.5))
                        Logger.caching.info("🔄 SAFEGUARD RECOVER: Attempting to restart caching process")
                        // The function will get called again soon by the regular flow, so we just need to
                        // ensure the state is clean for that call.
                    }
                }
            }

            return
        }

        // Make sure we have identifiers before trying to cache
        guard !identifiers.isEmpty else {
            Logger.caching.error("Cannot cache videos: identifiers array is empty")
            return
        }
        
        // Get current cache state
        let cacheCount = await cacheManager.cacheCount()
        let maxCache = await cacheManager.getMaxCacheSize()
        
        Logger.caching.info("VideoCacheService.ensureVideosAreCached: current size: \(cacheCount)/\(maxCache)")
        
        // Step 1: First, cancel any existing cache task to avoid conflicts
        cacheTask?.cancel()
        cacheTask = nil
        
        // Step 2: If the cache is empty, we need to load at least one video directly
        // This is critical for initialization to complete
        if cacheCount == 0 {
            Logger.caching.info("VideoCacheService: Cache empty, trying to load first video immediately")
            
            // Try up to 3 times to load a video (in case of network issues)
            var videoLoaded = false
            var attempts = 0
            
            while !videoLoaded && attempts < 3 {
                do {
                    attempts += 1
                    Logger.caching.info("VideoCacheService: Loading attempt \(attempts)")
                    
                    // Safety check - get a fresh identifier
                    guard let identifier = await archiveService.getRandomIdentifier(from: identifiers) else {
                        Logger.caching.error("VideoCacheService: No identifiers available on attempt \(attempts)")
                        try? await Task.sleep(for: .seconds(0.5))
                        continue
                    }
                    
                    // Use the VideoLoadingService instead of our internal method for more reliability
                    let service = VideoLoadingService(archiveService: archiveService, cacheManager: cacheManager)
                    let video = try await service.loadCompleteCachedVideo(for: identifier)
                    
                    // Directly add to cache to ensure it's added immediately
                    await cacheManager.addCachedVideo(video)
                    
                    // Verify the video was added
                    let newCount = await cacheManager.cacheCount()
                    if newCount > 0 {
                        Logger.caching.info("VideoCacheService: Successfully added video to cache, count now: \(newCount)")
                        videoLoaded = true
                    } else {
                        Logger.caching.error("VideoCacheService: Video not added to cache, retrying...")
                    }
                } catch {
                    Logger.caching.error("VideoCacheService: Failed to load video on attempt \(attempts): \(error.localizedDescription)")
                    try? await Task.sleep(for: .seconds(0.5))
                }
            }
            
            // If we still couldn't load a video after multiple attempts, log this critical failure
            if !videoLoaded {
                Logger.caching.error("⚠️ CRITICAL: Could not load any videos after multiple attempts")
            }
        }
        
        // Step 3: Start background task to fill the remainder of the cache
        // Only start this task if we need more videos AND the first video is ready
        // and preloading is complete (if applicable)
        let currentCount = await cacheManager.cacheCount()
        if currentCount < maxCache {
            // First cleanup any existing cache task to prevent resource leaks
            if let task = cacheTask, !task.isCancelled {
                Logger.caching.info("🧹 CLEANUP: Cancelling existing cache task before starting a new one")
                task.cancel()
                cacheTask = nil
            }

            // Check first video ready state
            Logger.caching.info("🔍 STATUS: Checking if first video is ready. isFirstVideoReady = \(self.isFirstVideoReady)")
            if !self.isFirstVideoReady {
                Logger.caching.info("⏸️ PAUSED: First video not yet playing, delaying background cache filling")
                return
            }

            // Check preloading completion state
            Logger.caching.info("🔍 STATUS: Checking if preloading is complete. isPreloadingComplete = \(self.isPreloadingComplete)")
            if !self.isPreloadingComplete {
                Logger.caching.info("⏸️ PAUSED: Preloading not yet complete, delaying background cache filling")
                return
            }

            Logger.caching.info("✅ STATUS: First video is ready and preloading is complete, proceeding with cache filling")
            
            Logger.caching.info("🔄 CACHE TASK: Starting background task to fill cache to \(maxCache) videos")

            // Log timestamp for performance tracking
            let cacheStartTime = CFAbsoluteTimeGetCurrent()
            Logger.caching.info("⏱️ TIMING: Cache filling starting at \(cacheStartTime)")

            // Notify that caching is starting (ensure the indicator shows)
            await notifyCachingStarted()

            // Use a new task for background filling
            cacheTask = Task {
                Logger.caching.info("🔄 CACHE TASK: Background task started")
                
                // Loop until we've filled the cache or are canceled
                var consecutiveFailures = 0
                while !Task.isCancelled {
                    // Check if preloading has started - if so, immediately exit the loop
                    if isPreloadingInProgress {
                        Logger.caching.info("🛑 CACHE TASK: Preloading has started, aborting cache task immediately")
                        break
                    }

                    // Check current count
                    let count = await cacheManager.cacheCount()
                    Logger.caching.info("VideoCacheService background task: Current cache count: \(count)/\(maxCache)")

                    // If cache is full, we're done
                    if count >= maxCache {
                        Logger.caching.info("Cache is full (\(count)/\(maxCache)), background caching complete")
                        break
                    }
                    
                    // If we've had too many consecutive failures, take a longer break
                    if consecutiveFailures >= 5 {
                        Logger.caching.warning("Too many consecutive failures, taking a longer break")
                        try? await Task.sleep(for: .seconds(2.0))
                        consecutiveFailures = 0
                        continue
                    }
                    
                    // Add one more video
                    do {
                        // Check if we've been canceled before starting a potentially expensive caching operation
                        if Task.isCancelled {
                            Logger.caching.info("🛑 CACHE TASK: Task was canceled before starting a new video cache operation")
                            break
                        }

                        // Check hard block - immediately exit if preloading has started
                        if isPreloadingInProgress {
                            Logger.caching.info("🛑 CACHE TASK: Preloading has started, aborting cache task immediately")
                            break
                        }

                        // Check if preloading is complete before proceeding with each item
                        if !isPreloadingComplete {
                            Logger.caching.info("⏸️ CACHE TASK: Pausing cache operations - preloading is in progress")
                            // Take a short break before checking again
                            try? await Task.sleep(for: .seconds(0.5))
                            continue
                        }

                        // Time the caching of a single video
                        let singleCacheStart = CFAbsoluteTimeGetCurrent()

                        try await self.cacheRandomVideo(cacheManager: cacheManager, archiveService: archiveService, identifiers: identifiers)

                        let singleCacheEnd = CFAbsoluteTimeGetCurrent()
                        let singleCacheDuration = singleCacheEnd - singleCacheStart

                        let newCount = await cacheManager.cacheCount()
                        Logger.caching.info("✅ CACHE TASK: Added video to cache in \(singleCacheDuration.formatted(.number.precision(.fractionLength(3)))) seconds, now at \(newCount)/\(maxCache)")
                        consecutiveFailures = 0 // Reset failure counter on success
                    } catch {
                        Logger.caching.error("Failed to cache video: \(error.localizedDescription)")
                        consecutiveFailures += 1
                        try? await Task.sleep(for: .seconds(0.5))
                    }
                }
            }
        }
    }
}