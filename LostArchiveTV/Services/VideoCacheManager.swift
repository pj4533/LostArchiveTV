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

    func peekFirstCachedVideo() -> CachedVideo? {
        // Get the first video without removing it
        guard !cachedVideos.isEmpty else {
            Logger.caching.info("⚠️ CACHE: Attempted to peek at video in empty cache")
            return nil
        }

        Logger.caching.info("👁️ CACHE: Peeking at first video in cache: \(self.cachedVideos[0].identifier) (not removing)")
        return cachedVideos[0]
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

        // Calculate how many videos we need to add
        let videosToAdd = self.maxCachedVideos - cacheCount

        // Simple logic: if cache isn't full, add more videos until it is
        if videosToAdd > 0 {
            Logger.caching.info("Need to add \(videosToAdd) videos to cache")

            // Track already cached identifiers to avoid duplicates
            let existingIdentifiers = Set(cachedVideos.map { $0.identifier })

            // Start filling the cache
            var added = 0
            var attempts = 0
            let maxAttempts = 20 // Prevent infinite loops

            // Loop until we've added enough videos or too many attempts
            while added < videosToAdd && attempts < maxAttempts {
                attempts += 1

                // FIXED: Always use getRandomIdentifier() to respect collection weighting
                guard let randomIdentifier = await archiveService.getRandomIdentifier(from: identifiers) else {
                    Logger.caching.error("Failed to get random identifier, aborting cache fill")
                    break
                }

                // Skip if this identifier is already in the cache
                if !existingIdentifiers.contains(randomIdentifier.identifier) {
                    do {
                        // Attempt to preload the video
                        try await preloadVideo(for: randomIdentifier, using: archiveService)
                        added += 1
                        Logger.caching.info("Added video \(added) of \(videosToAdd): \(randomIdentifier.identifier) from \(randomIdentifier.collection)")
                    } catch {
                        Logger.caching.error("Failed to preload video \(randomIdentifier.identifier): \(error.localizedDescription)")
                    }
                } else {
                    Logger.caching.info("Skipping already cached identifier: \(randomIdentifier.identifier)")
                }
            }

            // Log if we couldn't add enough videos
            if added < videosToAdd {
                Logger.caching.warning("Could only add \(added) of \(videosToAdd) videos after \(attempts) attempts")
            }

            Logger.caching.info("Cache filling complete, now at \(self.cacheCount())/\(self.maxCachedVideos)")
        } else {
            Logger.caching.info("Cache is already full (\(cacheCount)/\(self.maxCachedVideos)), no need to add more videos")
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
        var options: [String: Any] = [:]
        if EnvironmentService.shared.hasArchiveCookie {
            let headers: [String: String] = [
               "Cookie": EnvironmentService.shared.archiveCookie
            ]
            options["AVURLAssetHTTPHeaderFieldsKey"] = headers
        }
        // Create an asset from the URL
        let asset = AVURLAsset(url: videoURL, options: options)
        
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
        
        // Count unique video files
        let allVideoFiles = metadata.files.filter {
            $0.name.hasSuffix(".mp4") ||
            $0.format == "h.264 IA" ||
            $0.format == "h.264" ||
            $0.format == "MPEG4"
        }

        // Count unique file base names
        var uniqueBaseNames = Set<String>()
        for file in allVideoFiles {
            let baseName = file.name.replacingOccurrences(of: "\\.mp4$", with: "", options: .regularExpression)
            uniqueBaseNames.insert(baseName)
        }

        // Create and store the cached video
        let cachedVideo = CachedVideo(
            identifier: identifier.identifier,
            collection: identifier.collection,
            metadata: metadata,
            mp4File: mp4File,
            videoURL: videoURL,
            asset: asset,
            startPosition: randomStart,
            addedToFavoritesAt: nil,
            totalFiles: uniqueBaseNames.count
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

    /// Advances the cache window by removing the oldest item and ensuring the cache is refilled
    /// This implements a sliding window approach to cache management
    /// Called after a video transition to maintain cache state and avoid emptying/refilling
    func advanceCacheWindow(archiveService: ArchiveService, identifiers: [ArchiveIdentifier]) async {
        // Log initial cache state with timestamp for better debugging
        let startTime = CFAbsoluteTimeGetCurrent()
        Logger.caching.info("📊 CACHE WINDOW: Starting cache advancement at \(startTime). Current cache size: \(self.cachedVideos.count)")

        // Calculate target cache size before doing anything
        let targetSize = self.maxCachedVideos
        Logger.caching.info("📊 CACHE WINDOW: Target cache size: \(targetSize)")

        // This is the key issue: When peeking at videos in the cache for preloading, we
        // don't actually remove them. But when a video is played, we need to remove it
        // from the cache (since it's already being played, it shouldn't be in the preload queue)

        // IMPROVED: More aggressive duplicate cleanup to prevent edge cases
        var foundDuplicates = false
        if cachedVideos.count > 1 {
            // First identify all duplicates
            var uniqueIdentifiers = Set<String>()
            var indexesToRemove = [Int]()

            for (index, video) in cachedVideos.enumerated().reversed() {
                if uniqueIdentifiers.contains(video.identifier) {
                    Logger.caching.warning("🚨 DUPLICATE CLEANUP: Found duplicate video in cache: \(video.identifier) at position \(index)")
                    indexesToRemove.append(index)
                    foundDuplicates = true
                } else {
                    uniqueIdentifiers.insert(video.identifier)
                }
            }

            // Then remove them safely
            if foundDuplicates {
                for index in indexesToRemove {
                    if index < cachedVideos.count {
                        let duplicate = cachedVideos.remove(at: index)
                        Logger.caching.warning("🧹 DUPLICATE CLEANUP: Removed duplicate: \(duplicate.identifier)")
                    }
                }
                Logger.caching.warning("🧹 DUPLICATE CLEANUP: Removed \(indexesToRemove.count) duplicates. New size: \(self.cachedVideos.count)")
            }
        }

        // Log current cache state for diagnostics
        if !cachedVideos.isEmpty {
            var cacheState = ""
            for (i, video) in cachedVideos.enumerated() {
                cacheState += "[\(i):\(video.identifier)] "
            }
            Logger.caching.info("📋 CACHE STATE BEFORE REMOVAL: \(cacheState)")
        }

        // Only remove the oldest video if we have something in the cache
        if !cachedVideos.isEmpty {
            // 1. Remove the oldest (first) item if we have any videos
            let oldestVideo = cachedVideos.removeFirst()
            Logger.caching.info("📤 CACHE WINDOW: Removed oldest video: \(oldestVideo.identifier)")
        } else {
            Logger.caching.warning("⚠️ CACHE WINDOW: Cache is empty, nothing to remove. THIS MAY INDICATE A PROBLEM.")
        }

        // Log cache state after removal
        Logger.caching.info("📊 CACHE WINDOW: After removal, cache size: \(self.cachedVideos.count)")

        // Calculate exactly how many videos we need to add to reach our target
        let videosToAdd = targetSize - self.cachedVideos.count
        Logger.caching.info("🔢 CACHE WINDOW: Need to add exactly \(videosToAdd) videos to reach target of \(targetSize)")

        if videosToAdd > 0 {
            // 2. Use getRandomIdentifier() to select videos with proper weighting

            // Track already cached identifiers to avoid duplicates
            let existingIdentifiers = Set(cachedVideos.map { $0.identifier })

            // Start filling the cache
            var added = 0
            var attempts = 0
            let maxAttempts = 20 // safety limit to prevent infinite loops

            // Continue until we've added enough videos or hit the attempt limit
            while added < videosToAdd && attempts < maxAttempts {
                attempts += 1

                // FIXED: Always use getRandomIdentifier() for proper collection weighting
                guard let randomIdentifier = await archiveService.getRandomIdentifier(from: identifiers) else {
                    Logger.caching.error("❌ CACHE WINDOW: Failed to get random identifier, aborting")
                    break
                }

                // Skip if this identifier is already in the cache
                if !existingIdentifiers.contains(randomIdentifier.identifier) {
                    do {
                        // Attempt to preload the video
                        try await preloadVideo(for: randomIdentifier, using: archiveService)
                        added += 1
                        Logger.caching.info("✅ CACHE WINDOW: Added video \(added)/\(videosToAdd): \(randomIdentifier.identifier) from \(randomIdentifier.collection)")
                    } catch {
                        Logger.caching.error("❌ CACHE WINDOW: Failed to add video \(randomIdentifier.identifier): \(error.localizedDescription)")
                    }
                } else {
                    Logger.caching.info("⏩ CACHE WINDOW: Skipping already cached identifier: \(randomIdentifier.identifier)")
                }
            }

            // Force additional logging if we couldn't add enough videos
            if added < videosToAdd {
                Logger.caching.warning("⚠️ CACHE WINDOW: Could only add \(added) of \(videosToAdd) videos after \(attempts) attempts")
            }
        }

        // Log final cache state
        Logger.caching.info("📊 CACHE WINDOW: Final cache size after window advancement: \(self.cachedVideos.count)/\(targetSize)")
    }
}
