//
//  VideoCacheService+CacheOperations.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 5/31/25.
//

import Foundation
import AVFoundation
import OSLog

// MARK: - Cache Operations
extension VideoCacheService {
    func cacheRandomVideo(cacheManager: VideoCacheManager, archiveService: ArchiveService, identifiers: [ArchiveIdentifier]) async throws {
        // Early check: if all identifiers are failed, throw an error
        let failedCount = await getPermanentlyFailedIdentifiers().count
        if failedCount >= identifiers.count {
            Logger.caching.error("⚠️ CACHE: All \(identifiers.count) identifiers have been marked as permanently failed")
            throw NSError(domain: "CacheError", code: 7, userInfo: [NSLocalizedDescriptionKey: "All identifiers have failed"])
        }
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

        // Try to get a non-failed identifier (with retry logic)
        var randomArchiveIdentifier: ArchiveIdentifier?
        var attempts = 0
        let maxAttempts = min(10, identifiers.count) // Don't try more than 10 times or the number of identifiers
        
        while attempts < maxAttempts {
            attempts += 1
            
            guard let candidate = await archiveService.getRandomIdentifier(from: identifiers) else {
                Logger.caching.error("No identifiers available for caching")
                throw NSError(domain: "CacheError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No identifiers available"])
            }
            
            // Check if this identifier has been marked as permanently failed
            if await isIdentifierPermanentlyFailed(candidate.identifier) {
                Logger.caching.info("⏭️ CACHE: Skipping permanently failed identifier: \(candidate.identifier) (attempt \(attempts)/\(maxAttempts))")
                continue
            }
            
            // Found a non-failed identifier
            randomArchiveIdentifier = candidate
            break
        }
        
        guard let randomArchiveIdentifier = randomArchiveIdentifier else {
            Logger.caching.error("⚠️ CACHE: Could not find a non-failed identifier after \(maxAttempts) attempts")
            throw NSError(domain: "CacheError", code: 6, userInfo: [NSLocalizedDescriptionKey: "All attempted identifiers have permanently failed"])
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
        let mp4Files = try await archiveService.findPlayableFiles(in: metadata)

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
}