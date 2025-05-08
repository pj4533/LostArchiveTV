//
//  VideoCacheManager.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import Foundation
import AVFoundation
import OSLog

actor VideoCacheManager {
    private var cachedVideos: [CachedVideo] = []
    private var maxCachedVideos = 3
    
    func getCachedVideos() -> [CachedVideo] {
        return cachedVideos
    }
    
    func addCachedVideo(_ video: CachedVideo) {
        cachedVideos.append(video)
        Logger.caching.info("📥 CACHE: Added video to cache: \(video.identifier), new cache size: \(self.cachedVideos.count)")
        
        // Log detailed cache state after addition
        var cachedIdentifiers = ""
        for (index, cachedVideo) in cachedVideos.enumerated() {
            cachedIdentifiers += "[\(index)] \(cachedVideo.identifier) "
        }
        Logger.caching.info("📋 CACHE STATE: \(cachedIdentifiers)")
    }
    
    /// Enhanced method to ensure videos are properly cached
    /// - Parameters:
    ///   - identifiers: List of archive identifiers to cache
    ///   - archiveService: The archive service to use for fetching metadata and files
    func ensureVideosAreCached(identifiers: [ArchiveIdentifier], using archiveService: ArchiveService) async {
        // Make sure we have identifiers before trying to preload
        guard !identifiers.isEmpty else {
            Logger.caching.error("Cannot preload videos: identifiers array is empty")
            return
        }
        
        // Get current cache state
        let cacheCount = self.cacheCount()
        
        Logger.caching.info("Ensuring videos are cached, current size: \(cacheCount)/\(self.maxCachedVideos)")
        
        // Simple logic: if cache isn't full, add more videos until it is
        if cacheCount < self.maxCachedVideos {
            // Start filling the cache from the provided identifiers
            var i = 0
            while cacheCount + i < self.maxCachedVideos && i < identifiers.count {
                do {
                    // Attempt to preload the video at the current index
                    try await preloadVideo(for: identifiers[i], using: archiveService)
                    i += 1
                } catch {
                    Logger.caching.error("Failed to preload video: \(error.localizedDescription)")
                    i += 1 // Skip this video and try the next one
                }
            }
            
            Logger.caching.info("Cache filling complete, now at \(self.cacheCount())/\(self.maxCachedVideos)")
        }
    }
    
    /// Preloads a single video from an identifier
    /// - Parameters:
    ///   - identifier: The archive identifier to preload
    ///   - archiveService: The archive service to use
    /// - Returns: The preloaded cached video
    private func preloadVideo(for identifier: ArchiveIdentifier, using archiveService: ArchiveService) async throws -> CachedVideo {
        Logger.caching.info("Preloading video: \(identifier.identifier) from collection: \(identifier.collection)")
        
        // Fetch metadata
        let metadata = try await archiveService.fetchMetadata(for: identifier.identifier)
        
        // Find MP4 file
        let mp4Files = await archiveService.findPlayableFiles(in: metadata)
        
        guard !mp4Files.isEmpty else {
            Logger.caching.error("No MP4 file found for \(identifier.identifier)")
            throw NSError(domain: "PreloadError", code: 2, userInfo: [NSLocalizedDescriptionKey: "No MP4 file found"])
        }
        
        // Select a file prioritizing longer durations
        guard let mp4File = await archiveService.selectFilePreferringLongerDurations(from: mp4Files) else {
            Logger.caching.error("Failed to select file from available mp4Files")
            throw NSError(domain: "PreloadError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to select file"])
        }
        
        // Create URL and asset
        guard let videoURL = await archiveService.getFileDownloadURL(for: mp4File, identifier: identifier.identifier) else {
            throw NSError(domain: "PreloadError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not create URL"])
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
        Logger.caching.info("VIDEO TIMING (PRELOAD): Duration=\(estimatedDuration.formatted(.number.precision(.fractionLength(1))))s, Offset=\(randomStart.formatted(.number.precision(.fractionLength(1))))s (\(identifier.identifier))")
        
        // Start preloading the asset by requesting its duration (which loads data)
        _ = try await asset.load(.duration)
        
        // Create and store the cached video
        let cachedVideo = CachedVideo(
            identifier: identifier.identifier,
            collection: identifier.collection,
            metadata: metadata,
            mp4File: mp4File,
            videoURL: videoURL,
            asset: asset,
            playerItem: playerItem,
            startPosition: randomStart,
            addedToFavoritesAt: nil
        )
        
        // Store in the cache
        Logger.caching.info("Successfully preloaded video: \(identifier.identifier) from collection: \(identifier.collection), adding to cache")
        self.addCachedVideo(cachedVideo)
        
        return cachedVideo
    }
    
    func removeFirstCachedVideo() -> CachedVideo? {
        guard !cachedVideos.isEmpty else { 
            Logger.caching.info("⚠️ CACHE: Attempted to remove video from empty cache")
            return nil 
        }
        let video = cachedVideos.removeFirst()
        Logger.caching.info("📤 CACHE: Removed video from cache: \(video.identifier), remaining cache size: \(self.cachedVideos.count)")
        
        // Log remaining cache state after removal
        if !cachedVideos.isEmpty {
            var cachedIdentifiers = ""
            for (index, cachedVideo) in cachedVideos.enumerated() {
                cachedIdentifiers += "[\(index)] \(cachedVideo.identifier) "
            }
            Logger.caching.info("📋 CACHE STATE AFTER REMOVAL: \(cachedIdentifiers)")
        } else {
            Logger.caching.info("📋 CACHE STATE AFTER REMOVAL: [empty]")
        }
        return video
    }
    
    func removeVideo(identifier: String) {
        let beforeCount = cachedVideos.count
        cachedVideos.removeAll { $0.identifier == identifier }
        let afterCount = cachedVideos.count
        
        if beforeCount != afterCount {
            Logger.caching.info("Removed video \(identifier) from cache - remaining: \(afterCount)")
        } else {
            Logger.caching.debug("Attempted to remove video \(identifier) from cache, but it wasn't found")
        }
    }
    
    func clearCache() {
        Logger.caching.info("Clearing video cache (\(self.cachedVideos.count) videos)")
        cachedVideos.removeAll()
    }
    
    func getMaxCacheSize() -> Int {
        return maxCachedVideos
    }
    
    func cacheCount() -> Int {
        return cachedVideos.count
    }
    
    func isCacheEmpty() -> Bool {
        return cachedVideos.isEmpty
    }
}
