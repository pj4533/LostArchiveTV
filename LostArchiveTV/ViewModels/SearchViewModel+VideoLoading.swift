//
//  SearchViewModel+VideoLoading.swift
//  LostArchiveTV
//
//  Created by Claude on 2025-06-30.
//

import Foundation
import AVKit
import AVFoundation
import OSLog

extension SearchViewModel {
    // MARK: - Video Loading
    
    func playVideoAt(index: Int) {
        guard index >= 0, index < searchResults.count else { return }
        
        Logger.caching.info("SearchViewModel.playVideoAt: Playing video at index \(index)")
        isLoading = true
        currentIndex = index
        currentResult = searchResults[index]
        
        // Ensure the transition manager is initialized
        if transitionManager == nil {
            transitionManager = VideoTransitionManager()
        }
        
        Task {
            await loadVideo(for: searchResults[index].identifier)
            
            // Start preloading of adjacent videos - this helps ensure smooth swipe transitions
            try? await Task.sleep(for: .seconds(0.5))
            await ensureVideosAreCached()
            
            isLoading = false
            showingPlayer = true
        }
    }
    
    func loadVideo(for identifier: ArchiveIdentifier) async {
        do {
            isLoading = true

            Logger.caching.info("Loading video for identifier: \(identifier.identifier)")

            // Create a CachedVideo from the search result
            let cachedVideo = try await createCachedVideo(for: identifier)

            // Store a reference to the cached video
            _currentCachedVideo = cachedVideo

            // Update totalFiles from cached video
            self.totalFiles = cachedVideo.totalFiles
            Logger.files.info("📊 SEARCH PLAYER: Updated totalFiles to \(cachedVideo.totalFiles) from CachedVideo")

            // Create player item and player
            let playerItem = AVPlayerItem(asset: cachedVideo.asset)
            let newPlayer = AVPlayer(playerItem: playerItem)

            // Set the player and seek to start position
            player = newPlayer

            // Seek to the specified position
            let startTime = CMTime(seconds: cachedVideo.startPosition, preferredTimescale: 600)
            await newPlayer.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)

            // Start playback
            newPlayer.play()

            // Update metadata properties
            currentIdentifier = identifier.identifier
            currentFilename = cachedVideo.mp4File.name
            if let result = searchResults.first(where: { $0.identifier.identifier == identifier.identifier }) {
                currentTitle = result.title
                currentDescription = result.description
                currentCollection = identifier.collection
            }

            
            isLoading = false
        } catch {
            handleError(error)
            Logger.caching.error("Failed to load video: \(error.localizedDescription)")
            isLoading = false
        }
    }
    
    // Method to load a video for a specific identifier
    internal func loadFreshRandomVideo(for identifier: ArchiveIdentifier) async throws -> (identifier: String, collection: String, title: String, description: String, filename: String, asset: AVAsset, startPosition: Double) {
        Logger.metadata.info("Loading video for specific identifier: \(identifier.identifier) from collection: \(identifier.collection)")
        
        let metadataStartTime = CFAbsoluteTimeGetCurrent()
        let metadata = try await archiveService.fetchMetadata(for: identifier.identifier)
        let metadataTime = CFAbsoluteTimeGetCurrent() - metadataStartTime
        Logger.network.info("Fetched metadata in \(String(format: "%.4f", metadataTime)) seconds")
        
        // Find MP4 file
        let mp4Files = try await archiveService.findPlayableFiles(in: metadata)
        
        guard !mp4Files.isEmpty else {
            let error = "No MP4 file found in the archive"
            Logger.metadata.error("\(error)")
            throw NSError(domain: "VideoPlayerError", code: 1, userInfo: [NSLocalizedDescriptionKey: error])
        }
        
        // Select a file prioritizing longer durations
        guard let mp4File = await archiveService.selectFilePreferringLongerDurations(from: mp4Files) else {
            let error = "Failed to select file from available mp4Files"
            Logger.metadata.error("\(error)")
            throw NSError(domain: "VideoPlayerError", code: 1, userInfo: [NSLocalizedDescriptionKey: error])
        }
        
        guard let videoURL = await archiveService.getFileDownloadURL(for: mp4File, identifier: identifier.identifier) else {
            let error = "Could not create video URL"
            Logger.metadata.error("\(error)")
            throw NSError(domain: "VideoPlayerError", code: 2, userInfo: [NSLocalizedDescriptionKey: error])
        }
        
        // Create asset with optimized loading
        let assetStartTime = CFAbsoluteTimeGetCurrent()
        var options: [String: Any] = [:]
        if EnvironmentService.shared.hasArchiveCookie {
            let headers: [String: String] = [
               "Cookie": EnvironmentService.shared.archiveCookie
            ]
            options["AVURLAssetHTTPHeaderFieldsKey"] = headers
        }
        // Create an asset from the URL
        let asset = AVURLAsset(url: videoURL, options: options)
        Logger.videoPlayback.debug("Created AVURLAsset")
        
        // Set title and description from metadata
        let title = metadata.metadata?.title ?? identifier.identifier
        let description = metadata.metadata?.description ?? "Internet Archive video"
        let filename = mp4File.name
        
        // Get estimated duration from metadata
        let estimatedDuration = await archiveService.estimateDuration(fromFile: mp4File)
        
        // Use more conservative duration to avoid seeking too close to the end
        let safetyMargin = min(estimatedDuration * 0.2, 60.0)
        let maxStartTime = max(0, estimatedDuration - safetyMargin)
        let safeMaxStartTime = max(0, min(maxStartTime, estimatedDuration - 40))
        
        // If video is very short, start from beginning
        let randomStart = safeMaxStartTime > 10 ? Double.random(in: 0..<safeMaxStartTime) : 0
        
        // Log video duration and offset information in a single line for easy identification
        Logger.videoPlayback.info("VIDEO TIMING: Duration=\(String(format: "%.1f", estimatedDuration))s, Offset=\(String(format: "%.1f", randomStart))s (\(identifier.identifier))")
        
        let assetTime = CFAbsoluteTimeGetCurrent() - assetStartTime
        Logger.videoPlayback.info("Asset setup completed in \(String(format: "%.4f", assetTime)) seconds")
        
        return (
            identifier.identifier,
            identifier.collection,
            title,
            description,
            filename,
            asset,
            randomStart
        )
    }
}