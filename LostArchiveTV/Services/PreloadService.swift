//
//  PreloadService.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import Foundation
import AVFoundation
import OSLog

actor PreloadService {
    private var preloadTask: Task<Void, Never>?
    
    func ensureVideosAreCached(cacheManager: VideoCacheManager, archiveService: ArchiveService, identifiers: [String]) async {
        // Make sure we have identifiers before trying to preload
        guard !identifiers.isEmpty else {
            Logger.caching.error("Cannot preload videos: identifiers array is empty")
            return
        }
        
        // Cancel any existing preload task
        preloadTask?.cancel()
        
        // Start a new preload task
        preloadTask = Task {
            let cacheCount = await cacheManager.cacheCount()
            Logger.caching.info("Starting cache preload for swipe interface, current cache size: \(cacheCount)")
            
            // Prioritize loading at least one video immediately
            if await cacheManager.isCacheEmpty() {
                Logger.caching.debug("Cache empty, prioritizing first video load")
                do {
                    try await self.preloadRandomVideo(cacheManager: cacheManager, archiveService: archiveService, identifiers: identifiers)
                } catch {
                    Logger.caching.error("Failed to preload first video: \(error.localizedDescription)")
                }
            }
            
            // Preload up to maxCachedVideos
            let maxCache = await cacheManager.getMaxCacheSize()
            
            // Continue preloading until we have enough cached videos
            var continuePreloading = true
            while !Task.isCancelled && continuePreloading {
                let currentCount = await cacheManager.cacheCount()
                continuePreloading = currentCount < maxCache
                
                if continuePreloading {
                    do {
                        try await self.preloadRandomVideo(cacheManager: cacheManager, archiveService: archiveService, identifiers: identifiers)
                    } catch {
                        Logger.caching.error("Failed to preload video: \(error.localizedDescription)")
                        // Give a short pause before trying again
                        try? await Task.sleep(for: .seconds(0.5)) // Reduced wait time for swipe interface
                    }
                }
            }
            
            let finalCount = await cacheManager.cacheCount()
            Logger.caching.info("Cache preload for swipe interface completed, cache size: \(finalCount)")
        }
    }
    
    func preloadRandomVideo(cacheManager: VideoCacheManager, archiveService: ArchiveService, identifiers: [String]) async throws {
        guard let randomIdentifier = await archiveService.getRandomIdentifier(from: identifiers) else {
            Logger.caching.error("No identifiers available for preloading")
            throw NSError(domain: "PreloadError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No identifiers available"])
        }
        
        Logger.caching.info("Preloading random video: \(randomIdentifier)")
        
        // Fetch metadata
        let metadata = try await archiveService.fetchMetadata(for: randomIdentifier)
        
        // Find MP4 file
        let mp4Files = await archiveService.findPlayableFiles(in: metadata)
        
        guard let mp4File = mp4Files.first else {
            Logger.caching.error("No MP4 file found for \(randomIdentifier)")
            throw NSError(domain: "PreloadError", code: 2, userInfo: [NSLocalizedDescriptionKey: "No MP4 file found"])
        }
        
        // Create URL and asset
        guard let videoURL = await archiveService.getFileDownloadURL(for: mp4File, identifier: randomIdentifier) else {
            throw NSError(domain: "PreloadError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not create URL"])
        }
        
        // Create optimized asset
        let asset = AVURLAsset(url: videoURL)
        
        // Create player item with caching configuration
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 60
        
        // Calculate a random start position
        let estimatedDuration = await archiveService.estimateDuration(fromFile: mp4File)
        let safetyMargin = min(estimatedDuration * 0.2, 60.0)
        let maxStartTime = max(0, estimatedDuration - safetyMargin)
        let safeMaxStartTime = max(0, min(maxStartTime, estimatedDuration - 40))
        let randomStart = safeMaxStartTime > 10 ? Double.random(in: 0..<safeMaxStartTime) : 0
        
        // Log the preloaded video's start position
        Logger.caching.info("Preloaded video start position: \(randomStart.formatted(.number.precision(.fractionLength(2)))) / \(estimatedDuration.formatted(.number.precision(.fractionLength(2)))) seconds (\((randomStart/estimatedDuration * 100).formatted(.number.precision(.fractionLength(2)))))%")
        
        // Start preloading the asset by requesting its duration (which loads data)
        _ = try await asset.load(.duration)
        
        // Create and store the cached video
        let cachedVideo = CachedVideo(
            identifier: randomIdentifier,
            metadata: metadata,
            mp4File: mp4File,
            videoURL: videoURL,
            asset: asset,
            playerItem: playerItem,
            startPosition: randomStart
        )
        
        // Store in the cache
        Logger.caching.info("Successfully preloaded video: \(randomIdentifier), adding to cache")
        await cacheManager.addCachedVideo(cachedVideo)
    }
    
    func cancelPreloading() {
        preloadTask?.cancel()
    }
}
