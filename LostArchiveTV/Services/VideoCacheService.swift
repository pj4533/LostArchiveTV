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
    private var cacheTask: Task<Void, Never>?

    // Track whether the first video is ready for playback
    private var isFirstVideoReady = false

    // Track whether preloading has completed for the current transition
    // Initialize to true to allow initial caching to proceed without waiting for preloading
    private var isPreloadingComplete = true

    // Flag to completely block ALL caching operations when preloading is in progress
    private var isPreloadingInProgress = false
    
    func ensureVideosAreCached(cacheManager: VideoCacheManager, archiveService: ArchiveService, identifiers: [ArchiveIdentifier]) async {
        // CRITICAL: Check hard block flag first - immediately bail out if preloading is in progress
        if isPreloadingInProgress {
            Logger.caching.info("🛑 HARD BLOCK: ensureVideosAreCached called while preloading is in progress - aborting immediately")
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

        // Since the cache task was canceled during preloading, it will need to be restarted
        // by the next call to ensureVideosAreCached
    }

    // Method to signal that preloading has started and caching should wait
    func setPreloadingStarted() {
        Logger.caching.info("⚠️ PRIORITY: Preloading started, activating hard block on ALL caching operations")

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
    }
    
    func cacheRandomVideo(cacheManager: VideoCacheManager, archiveService: ArchiveService, identifiers: [ArchiveIdentifier]) async throws {
        // CRITICAL: Check hard block flag first - immediately bail out if preloading is in progress
        if isPreloadingInProgress {
            Logger.caching.info("🛑 HARD BLOCK: cacheRandomVideo called while preloading is in progress - aborting immediately")
            throw NSError(domain: "CacheError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Preloading in progress"])
        }

        // Check for task cancellation before starting operation
        guard !Task.isCancelled else {
            Logger.caching.info("🛑 CACHE OPERATION: Task already cancelled, skipping caching operation")
            throw NSError(domain: "CacheError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Task cancelled"])
        }

        // Notify that caching has started
        await notifyCachingStarted()

        guard let randomArchiveIdentifier = await archiveService.getRandomIdentifier(from: identifiers) else {
            Logger.caching.error("No identifiers available for caching")
            throw NSError(domain: "CacheError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No identifiers available"])
        }

        let identifier = randomArchiveIdentifier.identifier
        let collection = randomArchiveIdentifier.collection

        Logger.caching.info("🔄 CACHE CHUNK: Starting to cache video: \(identifier) from collection: \(collection)")

        // Check for cancellation before starting metadata fetch (CHUNK BREAK POINT 1)
        if Task.isCancelled {
            Logger.caching.info("⏸️ CACHE CHUNK: Task cancelled before metadata fetch")
            throw NSError(domain: "CacheError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Task cancelled"])
        }

        // Check hard block - immediately abort if preloading has started
        if isPreloadingInProgress {
            Logger.caching.info("🛑 HARD BLOCK: Preloading in progress, aborting cache chunk immediately")
            throw NSError(domain: "CacheError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Preloading in progress"])
        }

        // Check preloading status before metadata fetch
        if !isPreloadingComplete {
            Logger.caching.info("⏸️ CACHE CHUNK: Preloading started, aborting cache operation")
            throw NSError(domain: "CacheError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Preloading in progress"])
        }

        // Fetch metadata - CHUNK 1
        Logger.caching.info("🔄 CACHE CHUNK 1: Fetching metadata for \(identifier)")
        let metadata = try await archiveService.fetchMetadata(for: identifier)

        // Check preloading status and cancellation after metadata fetch (CHUNK BREAK POINT 2)
        if isPreloadingInProgress {
            Logger.caching.info("🛑 HARD BLOCK: Preloading in progress, aborting cache chunk immediately")
            throw NSError(domain: "CacheError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Preloading in progress"])
        } else if !isPreloadingComplete || Task.isCancelled {
            Logger.caching.info("⏸️ CACHE CHUNK: Interrupted after metadata fetch")
            throw NSError(domain: "CacheError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Operation interrupted"])
        }

        // Find MP4 file - CHUNK 2
        Logger.caching.info("🔄 CACHE CHUNK 2: Finding playable files for \(identifier)")
        let mp4Files = await archiveService.findPlayableFiles(in: metadata)

        guard !mp4Files.isEmpty else {
            Logger.caching.error("No MP4 file found for \(identifier)")
            throw NSError(domain: "CacheError", code: 2, userInfo: [NSLocalizedDescriptionKey: "No MP4 file found"])
        }

        // Check preloading status and cancellation after finding files (CHUNK BREAK POINT 3)
        if isPreloadingInProgress {
            Logger.caching.info("🛑 HARD BLOCK: Preloading in progress, aborting cache chunk immediately")
            throw NSError(domain: "CacheError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Preloading in progress"])
        } else if !isPreloadingComplete || Task.isCancelled {
            Logger.caching.info("⏸️ CACHE CHUNK: Interrupted after finding files")
            throw NSError(domain: "CacheError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Operation interrupted"])
        }

        // Select a file prioritizing longer durations - CHUNK 3
        Logger.caching.info("🔄 CACHE CHUNK 3: Selecting best file for \(identifier)")
        guard let mp4File = await archiveService.selectFilePreferringLongerDurations(from: mp4Files) else {
            Logger.caching.error("Failed to select file from available mp4Files")
            throw NSError(domain: "CacheError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to select file"])
        }

        // Check preloading status and cancellation after file selection (CHUNK BREAK POINT 4)
        if isPreloadingInProgress {
            Logger.caching.info("🛑 HARD BLOCK: Preloading in progress, aborting cache chunk immediately")
            throw NSError(domain: "CacheError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Preloading in progress"])
        } else if !isPreloadingComplete || Task.isCancelled {
            Logger.caching.info("⏸️ CACHE CHUNK: Interrupted after file selection")
            throw NSError(domain: "CacheError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Operation interrupted"])
        }

        // Create URL and asset - CHUNK 4
        Logger.caching.info("🔄 CACHE CHUNK 4: Creating URL for \(identifier)")
        guard let videoURL = await archiveService.getFileDownloadURL(for: mp4File, identifier: identifier) else {
            throw NSError(domain: "CacheError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not create URL"])
        }
        
        // Check status before creating asset (CHUNK BREAK POINT 5)
        if isPreloadingInProgress {
            Logger.caching.info("🛑 HARD BLOCK: Preloading in progress, aborting cache chunk immediately")
            throw NSError(domain: "CacheError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Preloading in progress"])
        } else if !isPreloadingComplete || Task.isCancelled {
            Logger.caching.info("⏸️ CACHE CHUNK: Interrupted before creating asset")
            throw NSError(domain: "CacheError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Operation interrupted"])
        }

        // Create optimized asset - CHUNK 5
        Logger.caching.info("🔄 CACHE CHUNK 5: Creating asset for \(identifier)")
        let headers: [String: String] = [
           "Cookie": EnvironmentService.shared.archiveCookie
        ]
        // Create an asset from the URL
        let asset = AVURLAsset(url: videoURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])

        // Create player item with caching configuration
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 60

        // Check status before calculating position (CHUNK BREAK POINT 6)
        if isPreloadingInProgress {
            Logger.caching.info("🛑 HARD BLOCK: Preloading in progress, aborting cache chunk immediately")
            throw NSError(domain: "CacheError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Preloading in progress"])
        } else if !isPreloadingComplete || Task.isCancelled {
            Logger.caching.info("⏸️ CACHE CHUNK: Interrupted before calculating position")
            throw NSError(domain: "CacheError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Operation interrupted"])
        }

        // Calculate a random start position - CHUNK 6
        Logger.caching.info("🔄 CACHE CHUNK 6: Calculating position for \(identifier)")
        let estimatedDuration = await archiveService.estimateDuration(fromFile: mp4File)
        let safetyMargin = min(estimatedDuration * 0.2, 60.0)
        let maxStartTime = max(0, estimatedDuration - safetyMargin)
        let safeMaxStartTime = max(0, min(maxStartTime, estimatedDuration - 40))
        let randomStart = safeMaxStartTime > 10 ? Double.random(in: 0..<safeMaxStartTime) : 0

        // Log video duration and offset information in a single line for easy identification
        Logger.caching.info("VIDEO TIMING (CACHE): Duration=\(estimatedDuration.formatted(.number.precision(.fractionLength(1))))s, Offset=\(randomStart.formatted(.number.precision(.fractionLength(1))))s (\(identifier))")

        // Check status before loading asset (CHUNK BREAK POINT 7)
        if isPreloadingInProgress {
            Logger.caching.info("🛑 HARD BLOCK: Preloading in progress, aborting cache chunk immediately")
            throw NSError(domain: "CacheError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Preloading in progress"])
        } else if !isPreloadingComplete || Task.isCancelled {
            Logger.caching.info("⏸️ CACHE CHUNK: Interrupted before loading asset data")
            throw NSError(domain: "CacheError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Operation interrupted"])
        }

        // Start loading the asset by requesting its duration (which loads data) - CHUNK 7
        Logger.caching.info("🔄 CACHE CHUNK 7: Loading initial asset data for \(identifier)")
        _ = try await asset.load(.duration)
        
        // Check status before finalizing (CHUNK BREAK POINT 8)
        if isPreloadingInProgress {
            Logger.caching.info("🛑 HARD BLOCK: Preloading in progress, aborting cache chunk immediately")
            throw NSError(domain: "CacheError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Preloading in progress"])
        } else if !isPreloadingComplete || Task.isCancelled {
            Logger.caching.info("⏸️ CACHE CHUNK: Interrupted before processing file counts")
            throw NSError(domain: "CacheError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Operation interrupted"])
        }

        // Count unique video files - CHUNK 8
        Logger.caching.info("🔄 CACHE CHUNK 8: Counting video files for \(identifier)")
        var uniqueBaseNames = Set<String>()
        let videoFiles = metadata.files.filter {
            $0.name.hasSuffix(".mp4") ||
            $0.format == "h.264 IA" ||
            $0.format == "h.264" ||
            $0.format == "MPEG4"
        }

        for file in videoFiles {
            let baseName = file.name.replacingOccurrences(of: "\\.mp4$", with: "", options: .regularExpression)
            uniqueBaseNames.insert(baseName)
        }

        Logger.files.info("📊 CACHE: Found \(uniqueBaseNames.count) unique video files for \(identifier)")

        // Final check before creating the cached video object (CHUNK BREAK POINT 9)
        if isPreloadingInProgress {
            Logger.caching.info("🛑 HARD BLOCK: Preloading in progress, aborting cache chunk immediately")
            throw NSError(domain: "CacheError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Preloading in progress"])
        } else if !isPreloadingComplete || Task.isCancelled {
            Logger.caching.info("⏸️ CACHE CHUNK: Interrupted before creating cached video object")
            throw NSError(domain: "CacheError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Operation interrupted"])
        }

        // Create cached video object - CHUNK 9 (Final)
        Logger.caching.info("🔄 CACHE CHUNK 9: Creating cached video object for \(identifier)")
        let cachedVideo = CachedVideo(
            identifier: identifier,
            collection: collection,
            metadata: metadata,
            mp4File: mp4File,
            videoURL: videoURL,
            asset: asset,
            playerItem: playerItem,
            startPosition: randomStart,
            addedToFavoritesAt: nil,
            totalFiles: uniqueBaseNames.count
        )
        
        // Final check before storing in cache (CHUNK BREAK POINT 10)
        if isPreloadingInProgress {
            Logger.caching.info("🛑 HARD BLOCK: Preloading in progress, aborting cache chunk immediately")
            throw NSError(domain: "CacheError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Preloading in progress"])
        } else if !isPreloadingComplete || Task.isCancelled {
            Logger.caching.info("⏸️ CACHE CHUNK: Interrupted before storing in cache")
            throw NSError(domain: "CacheError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Operation interrupted"])
        }

        // Store in the cache - CHUNK 10 (Final)
        Logger.caching.info("✅ CACHE CHUNK 10: Successfully cached video: \(identifier) from collection: \(collection), adding to cache")
        await cacheManager.addCachedVideo(cachedVideo)

        // Notify that caching has completed
        await notifyCachingCompleted()
        Logger.caching.info("✅ CACHE OPERATION: Successfully completed all chunks for \(identifier)")
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
        isPreloadingComplete = true
        Logger.caching.info("▶️ RESUME: Reset isPreloadingComplete flag to true")
        // The next call to ensureVideosAreCached will restart caching
    }
}