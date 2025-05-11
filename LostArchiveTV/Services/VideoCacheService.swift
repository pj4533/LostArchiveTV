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
    
    func ensureVideosAreCached(cacheManager: VideoCacheManager, archiveService: ArchiveService, identifiers: [ArchiveIdentifier]) async {
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
        // or if this isn't the first video loading sequence
        let currentCount = await cacheManager.cacheCount()
        if currentCount < maxCache {
            // If first video isn't ready yet, don't start background task - wait for signal
            Logger.caching.info("VideoCacheService: Checking if first video is ready. isFirstVideoReady = \(self.isFirstVideoReady)")
            if !self.isFirstVideoReady {
                Logger.caching.info("VideoCacheService: First video not yet playing, delaying background cache filling")
                return
            }
            Logger.caching.info("VideoCacheService: First video is ready, proceeding with cache filling")
            
            Logger.caching.info("VideoCacheService: Starting background task to fill cache to \(maxCache) videos")

            // Notify that caching is starting (ensure the indicator shows)
            await notifyCachingStarted()

            // Use a new task for background filling
            cacheTask = Task {
                Logger.caching.info("VideoCacheService background task started")
                
                // Loop until we've filled the cache or are canceled
                var consecutiveFailures = 0
                while !Task.isCancelled {
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
                        try await self.cacheRandomVideo(cacheManager: cacheManager, archiveService: archiveService, identifiers: identifiers)
                        let newCount = await cacheManager.cacheCount()
                        Logger.caching.info("Added video to cache, now at \(newCount)/\(maxCache)")
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
    
    func cacheRandomVideo(cacheManager: VideoCacheManager, archiveService: ArchiveService, identifiers: [ArchiveIdentifier]) async throws {
        // Notify that caching has started
        await notifyCachingStarted()

        guard let randomArchiveIdentifier = await archiveService.getRandomIdentifier(from: identifiers) else {
            Logger.caching.error("No identifiers available for caching")
            throw NSError(domain: "CacheError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No identifiers available"])
        }

        let identifier = randomArchiveIdentifier.identifier
        let collection = randomArchiveIdentifier.collection

        Logger.caching.info("Caching random video: \(identifier) from collection: \(collection)")
        
        // Fetch metadata
        let metadata = try await archiveService.fetchMetadata(for: identifier)
        
        // Find MP4 file
        let mp4Files = await archiveService.findPlayableFiles(in: metadata)
        
        guard !mp4Files.isEmpty else {
            Logger.caching.error("No MP4 file found for \(identifier)")
            throw NSError(domain: "CacheError", code: 2, userInfo: [NSLocalizedDescriptionKey: "No MP4 file found"])
        }
        
        // Select a file prioritizing longer durations
        guard let mp4File = await archiveService.selectFilePreferringLongerDurations(from: mp4Files) else {
            Logger.caching.error("Failed to select file from available mp4Files")
            throw NSError(domain: "CacheError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to select file"])
        }
        
        // Create URL and asset
        guard let videoURL = await archiveService.getFileDownloadURL(for: mp4File, identifier: identifier) else {
            throw NSError(domain: "CacheError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not create URL"])
        }
        
        // Create optimized asset
        let headers: [String: String] = [
           "Cookie": EnvironmentService.shared.archiveCookie
        ]
        // Create an asset from the URL
        let asset = AVURLAsset(url: videoURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        
        // Create player item with caching configuration
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 60
        
        // Calculate a random start position
        let estimatedDuration = await archiveService.estimateDuration(fromFile: mp4File)
        let safetyMargin = min(estimatedDuration * 0.2, 60.0)
        let maxStartTime = max(0, estimatedDuration - safetyMargin)
        let safeMaxStartTime = max(0, min(maxStartTime, estimatedDuration - 40))
        let randomStart = safeMaxStartTime > 10 ? Double.random(in: 0..<safeMaxStartTime) : 0
        
        // Log video duration and offset information in a single line for easy identification
        Logger.caching.info("VIDEO TIMING (CACHE): Duration=\(estimatedDuration.formatted(.number.precision(.fractionLength(1))))s, Offset=\(randomStart.formatted(.number.precision(.fractionLength(1))))s (\(identifier))")
        
        // Start loading the asset by requesting its duration (which loads data)
        _ = try await asset.load(.duration)
        
        // Count unique video files by grouping files with the same base name
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

        // Create and store the cached video
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
        
        // Store in the cache
        Logger.caching.info("Successfully cached video: \(identifier) from collection: \(collection), adding to cache")
        await cacheManager.addCachedVideo(cachedVideo)

        // Notify that caching has completed
        await notifyCachingCompleted()
    }
    
    func cancelCaching() {
        cacheTask?.cancel()
    }

    /// Pauses the caching process during trim mode
    func pauseCaching() {
        Logger.caching.info("VideoCacheService: Pausing caching for trim mode")
        cacheTask?.cancel()
        cacheTask = nil
    }

    /// Resumes the caching process after trim mode ends
    func resumeCaching() {
        Logger.caching.info("VideoCacheService: Resuming caching after trim mode")
        // The next call to ensureVideosAreCached will restart caching
    }
}