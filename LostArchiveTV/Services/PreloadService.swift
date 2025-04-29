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
    
    func ensureVideosAreCached(cacheManager: VideoCacheManager, archiveService: ArchiveService, identifiers: [ArchiveIdentifier]) async {
        // Make sure we have identifiers before trying to preload
        guard !identifiers.isEmpty else {
            Logger.caching.error("Cannot preload videos: identifiers array is empty")
            return
        }
        
        // Get current cache state
        let cacheCount = await cacheManager.cacheCount()
        let maxCache = await cacheManager.getMaxCacheSize()
        
        Logger.caching.info("Ensuring videos are cached, current size: \(cacheCount)/\(maxCache)")
        
        // Simple logic: if cache isn't full, add more videos until it is
        if cacheCount < maxCache {
            // Cancel any existing preload task
            preloadTask?.cancel()
            
            // Start a new task to fill cache to exactly maxCache videos (3)
            preloadTask = Task {
                while !Task.isCancelled {
                    // Check current count
                    let count = await cacheManager.cacheCount()
                    
                    // If cache is full, we're done
                    if count >= maxCache {
                        Logger.caching.info("Cache is full (\(count)/\(maxCache)), preloading complete")
                        break
                    }
                    
                    // Add one more video
                    do {
                        try await self.preloadRandomVideo(cacheManager: cacheManager, archiveService: archiveService, identifiers: identifiers)
                        let newCount = await cacheManager.cacheCount()
                        Logger.caching.info("Added video to cache, now at \(newCount)/\(maxCache)")
                    } catch {
                        Logger.caching.error("Failed to preload video: \(error.localizedDescription)")
                        try? await Task.sleep(for: .seconds(0.5))
                    }
                }
            }
        }
    }
    
    func preloadRandomVideo(cacheManager: VideoCacheManager, archiveService: ArchiveService, identifiers: [ArchiveIdentifier]) async throws {
        guard let randomArchiveIdentifier = await archiveService.getRandomIdentifier(from: identifiers) else {
            Logger.caching.error("No identifiers available for preloading")
            throw NSError(domain: "PreloadError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No identifiers available"])
        }
        
        let identifier = randomArchiveIdentifier.identifier
        let collection = randomArchiveIdentifier.collection
        
        Logger.caching.info("Preloading random video: \(identifier) from collection: \(collection)")
        
        // Fetch metadata
        let metadata = try await archiveService.fetchMetadata(for: identifier)
        
        // Find MP4 file
        let mp4Files = await archiveService.findPlayableFiles(in: metadata)
        
        guard let mp4File = mp4Files.first else {
            Logger.caching.error("No MP4 file found for \(identifier)")
            throw NSError(domain: "PreloadError", code: 2, userInfo: [NSLocalizedDescriptionKey: "No MP4 file found"])
        }
        
        // Create URL and asset
        guard let videoURL = await archiveService.getFileDownloadURL(for: mp4File, identifier: identifier) else {
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
        
        // Log video duration and offset information in a single line for easy identification
        Logger.caching.info("VIDEO TIMING (PRELOAD): Duration=\(estimatedDuration.formatted(.number.precision(.fractionLength(1))))s, Offset=\(randomStart.formatted(.number.precision(.fractionLength(1))))s (\(identifier))")
        
        // Start preloading the asset by requesting its duration (which loads data)
        _ = try await asset.load(.duration)
        
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
            addedToFavoritesAt: nil
        )
        
        // Store in the cache
        Logger.caching.info("Successfully preloaded video: \(identifier) from collection: \(collection), adding to cache")
        await cacheManager.addCachedVideo(cachedVideo)
    }
    
    func cancelPreloading() {
        preloadTask?.cancel()
    }
}
