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
    
    func loadRandomVideo() async throws -> (identifier: String, collection: String, title: String, description: String, asset: AVAsset, startPosition: Double) {
        // Check if we have cached videos available
        if let cachedVideo = await cacheManager.removeFirstCachedVideo() {
            Logger.videoPlayback.info("Using cached video: \(cachedVideo.identifier) from collection: \(cachedVideo.collection)")
            
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
        return try await loadFreshRandomVideo()
    }
    
    private func loadFreshRandomVideo() async throws -> (identifier: String, collection: String, title: String, description: String, asset: AVAsset, startPosition: Double) {
        // Get random identifier
        let identifiers = try await archiveService.loadArchiveIdentifiers()
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
        let asset = AVURLAsset(url: videoURL)
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