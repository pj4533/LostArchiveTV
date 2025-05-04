//
//  VideoLoadingService.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import Foundation
import AVFoundation
import OSLog

actor VideoLoadingService {
    private let archiveService: ArchiveService
    private let cacheManager: VideoCacheManager
    
    init(archiveService: ArchiveService, cacheManager: VideoCacheManager) {
        self.archiveService = archiveService
        self.cacheManager = cacheManager
    }
    
    func loadIdentifiers() async throws -> [ArchiveIdentifier] {
        return try await archiveService.loadArchiveIdentifiers()
    }
    
    func loadIdentifiersWithUserPreferences() async throws -> [ArchiveIdentifier] {
        // Check if user has custom collection settings using the utility class
        let enabledCollections = CollectionPreferences.getEnabledCollections()
        
        if let enabledCollections = enabledCollections, !enabledCollections.isEmpty {
            // User has custom collections enabled
            Logger.metadata.info("Using user-defined collections: \(enabledCollections)")
            
            var identifiers: [ArchiveIdentifier] = []
            for collection in enabledCollections {
                do {
                    let collectionIdentifiers = try await archiveService.loadIdentifiersForCollection(collection)
                    identifiers.append(contentsOf: collectionIdentifiers)
                } catch {
                    Logger.metadata.error("Failed to load identifiers for collection \(collection): \(error.localizedDescription)")
                }
            }
            
            if identifiers.isEmpty {
                Logger.metadata.warning("No identifiers found in user-enabled collections, falling back to all collections")
                return try await archiveService.loadArchiveIdentifiers()
            }
            
            return identifiers
        } else {
            // Use default collection behavior
            Logger.metadata.info("Using default collection behavior")
            return try await archiveService.loadArchiveIdentifiers()
        }
    }
    
    /// Loads a complete CachedVideo object for a specific identifier
    /// - Parameter identifier: The archive identifier to load
    /// - Returns: A fully populated CachedVideo object ready for caching
    func loadCompleteCachedVideo(for identifier: ArchiveIdentifier) async throws -> CachedVideo {
        Logger.metadata.info("Loading complete cached video for: \(identifier.identifier) from collection: \(identifier.collection)")
        
        // Fetch metadata
        let metadata = try await archiveService.fetchMetadata(for: identifier.identifier)
        
        // Find MP4 file
        let mp4Files = await archiveService.findPlayableFiles(in: metadata)
        
        guard let mp4File = mp4Files.first else {
            Logger.metadata.error("No MP4 file found for \(identifier.identifier)")
            throw NSError(domain: "VideoLoadingError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No MP4 file found"])
        }
        
        guard let videoURL = await archiveService.getFileDownloadURL(for: mp4File, identifier: identifier.identifier) else {
            throw NSError(domain: "VideoLoadingError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not create URL"])
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
        
        // Try to load the asset's duration to ensure it's valid and preload some data
        try? await asset.load(.duration)
        
        // Create and return the cached video
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
        
        Logger.caching.info("Successfully created CachedVideo for \(identifier.identifier)")
        return cachedVideo
    }

    func loadRandomVideo() async throws -> (identifier: String, collection: String, title: String, description: String, asset: AVAsset, startPosition: Double) {
        Logger.videoPlayback.info("▶️ PLAYBACK: loadRandomVideo called - checking cache first")
        
        // Check if we have cached videos available
        if let cachedVideo = await cacheManager.removeFirstCachedVideo() {
            Logger.videoPlayback.info("🎯 PLAYBACK: Using CACHED video: \(cachedVideo.identifier) from collection: \(cachedVideo.collection)")
            
            // Return the cached video info
            return (
                cachedVideo.identifier,
                cachedVideo.collection,
                cachedVideo.title,
                cachedVideo.description,
                cachedVideo.asset,
                cachedVideo.startPosition
            )
        }
        
        // No cached videos available, load a random one
        Logger.videoPlayback.info("🔄 PLAYBACK: No cached videos available, loading FRESH video")
        let result = try await loadFreshRandomVideo()
        Logger.videoPlayback.info("✅ PLAYBACK: Successfully loaded fresh video: \(result.identifier)")
        return result
    }
    
    private func loadFreshRandomVideo() async throws -> (identifier: String, collection: String, title: String, description: String, asset: AVAsset, startPosition: Double) {
        // Get random identifier with user preferences
        let identifiers = try await loadIdentifiersWithUserPreferences()
        guard let randomArchiveIdentifier = await archiveService.getRandomIdentifier(from: identifiers) else {
            Logger.metadata.error("No identifiers available")
            throw NSError(domain: "VideoPlayerError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No identifiers available"])
        }
        
        let identifier = randomArchiveIdentifier.identifier
        let collection = randomArchiveIdentifier.collection
        
        Logger.metadata.info("Selected random video: \(identifier) from collection: \(collection)")
        
        let metadataStartTime = CFAbsoluteTimeGetCurrent()
        let metadata = try await archiveService.fetchMetadata(for: identifier)
        let metadataTime = CFAbsoluteTimeGetCurrent() - metadataStartTime
        Logger.network.info("Fetched metadata in \(metadataTime.formatted(.number.precision(.fractionLength(4)))) seconds")
        
        // Find MP4 file
        let mp4Files = await archiveService.findPlayableFiles(in: metadata)
        
        guard let mp4File = mp4Files.first else {
            let error = "No MP4 file found in the archive"
            Logger.metadata.error("\(error)")
            throw NSError(domain: "VideoPlayerError", code: 1, userInfo: [NSLocalizedDescriptionKey: error])
        }
        
        guard let videoURL = await archiveService.getFileDownloadURL(for: mp4File, identifier: identifier) else {
            let error = "Could not create video URL"
            Logger.metadata.error("\(error)")
            throw NSError(domain: "VideoPlayerError", code: 2, userInfo: [NSLocalizedDescriptionKey: error])
        }
        
        // Create asset with optimized loading
        let assetStartTime = CFAbsoluteTimeGetCurrent()
        let headers: [String: String] = [
           "Cookie": EnvironmentService.shared.archiveCookie
        ]
        // Create an asset from the URL
        let asset = AVURLAsset(url: videoURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        Logger.videoPlayback.debug("Created AVURLAsset")
        
        // Set title and description from metadata
        let title = metadata.metadata?.title ?? identifier
        let description = metadata.metadata?.description ?? "Internet Archive random video clip"
        
        // Get estimated duration from metadata
        let estimatedDuration = await archiveService.estimateDuration(fromFile: mp4File)
        
        // Use more conservative duration to avoid seeking too close to the end
        let safetyMargin = min(estimatedDuration * 0.2, 60.0)
        let maxStartTime = max(0, estimatedDuration - safetyMargin)
        let safeMaxStartTime = max(0, min(maxStartTime, estimatedDuration - 40))
        
        // If video is very short, start from beginning
        let randomStart = safeMaxStartTime > 10 ? Double.random(in: 0..<safeMaxStartTime) : 0
        
        // Log video duration and offset information in a single line for easy identification
        Logger.videoPlayback.info("VIDEO TIMING: Duration=\(estimatedDuration.formatted(.number.precision(.fractionLength(1))))s, Offset=\(randomStart.formatted(.number.precision(.fractionLength(1))))s (\(identifier))")
        
        let assetTime = CFAbsoluteTimeGetCurrent() - assetStartTime
        Logger.videoPlayback.info("Asset setup completed in \(assetTime.formatted(.number.precision(.fractionLength(4)))) seconds")
        
        return (
            identifier,
            collection,
            title,
            description,
            asset,
            randomStart
        )
    }
}
