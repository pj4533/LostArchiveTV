//
//  VideoPlayerViewModel.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import SwiftUI
import AVKit
import AVFoundation
import OSLog

@MainActor
class VideoPlayerViewModel: ObservableObject {
    // Services
    private let archiveService = ArchiveService()
    private let cacheManager = VideoCacheManager()
    private let preloadService = PreloadService()
    private let playbackManager = VideoPlaybackManager()
    
    // Published properties - these are the public interface of our ViewModel
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentIdentifier: String?
    @Published var currentTitle: String?
    @Published var currentDescription: String?
    
    // Archive.org video identifiers
    private var identifiers: [String] = []
    
    // MARK: - Initialization and Cleanup
    init() {
        // Configure audio session for proper playback on all devices
        playbackManager.setupAudioSession()
        
        // Load identifiers and start preloading videos when the ViewModel is initialized
        Task {
            // Load identifiers first
            await loadIdentifiers()
            
            // Brief delay to allow app to initialize fully
            try? await Task.sleep(for: .seconds(0.5))
            await ensureVideosAreCached()
        }
        
        // Configure logging
        Logger.videoPlayback.info("TikTok-style video player initialized with swipe interface")
    }
    
    // MARK: - Swipe Interface Support
    
    /// Prepares the player for swiping by ensuring multiple videos are cached
    func prepareForSwipe() {
        Logger.videoPlayback.debug("Preparing for swipe interactions")
        Task {
            await ensureVideosAreCached()
        }
    }
    
    /// Handles the completion of a swipe gesture
    func handleSwipeCompletion() {
        Logger.videoPlayback.info("Swipe gesture completed, loading next video")
        Task {
            await loadRandomVideo()
        }
    }
    
    // MARK: - Public Interface
    
    var player: AVPlayer? {
        playbackManager.player
    }
    
    var videoDuration: Double {
        playbackManager.videoDuration
    }
    
    // MARK: - Video Loading
    
    private func loadIdentifiers() async {
        identifiers = await archiveService.loadArchiveIdentifiers()
    }
    
    func loadRandomVideo() async {
        let overallStartTime = CFAbsoluteTimeGetCurrent()
        Logger.videoPlayback.info("Starting to load random video for swipe interface")
        isLoading = true
        errorMessage = nil
        
        // Clean up existing player
        playbackManager.cleanupPlayer()
        
        // Pre-emptively start caching next videos for smooth swipes
        Task {
            await ensureVideosAreCached()
        }
        
        // Check if we have cached videos available
        if let cachedVideo = await cacheManager.removeFirstCachedVideo() {
            Logger.videoPlayback.info("Using cached video: \(cachedVideo.identifier)")
            
            // Use the cached video
            currentIdentifier = cachedVideo.identifier
            currentTitle = cachedVideo.title
            currentDescription = cachedVideo.description
            
            // Setup player with the cached video's asset
            playbackManager.setupPlayer(with: cachedVideo.asset)
            
            // Start playback at the predetermined position
            let startPosition = cachedVideo.startPosition
            let startTime = CMTime(seconds: startPosition, preferredTimescale: 600)
            Logger.videoPlayback.info("Starting playback at time offset: \(startPosition.formatted(.number.precision(.fractionLength(2)))) seconds")
            
            let seekStartTime = CFAbsoluteTimeGetCurrent()
            playbackManager.seek(to: startTime) { [weak self] finished in
                let seekTime = CFAbsoluteTimeGetCurrent() - seekStartTime
                Logger.videoPlayback.info("Cached video seek completed in \(seekTime.formatted(.number.precision(.fractionLength(4)))) seconds")
                
                // Start playback
                self?.playbackManager.play()
                
                // Monitor buffer status
                if let playerItem = self?.playbackManager.player?.currentItem {
                    Task {
                        await self?.playbackManager.monitorBufferStatus(for: playerItem)
                    }
                }
            }
            
            isLoading = false
            
            // Start preloading the next video if needed
            await ensureVideosAreCached()
            
            let overallTime = CFAbsoluteTimeGetCurrent() - overallStartTime
            Logger.videoPlayback.info("Total cached video load time: \(overallTime.formatted(.number.precision(.fractionLength(4)))) seconds")
            return
        }
        
        // No cached videos available, load a random one
        guard let randomIdentifier = await archiveService.getRandomIdentifier(from: identifiers) else {
            Logger.metadata.error("No identifiers available")
            errorMessage = "No identifiers available. Make sure avgeeks_identifiers.json is in the app bundle."
            isLoading = false
            return
        }
        
        currentIdentifier = randomIdentifier
        Logger.metadata.info("Selected random video: \(randomIdentifier)")
        
        do {
            let metadataStartTime = CFAbsoluteTimeGetCurrent()
            let metadata = try await archiveService.fetchMetadata(for: randomIdentifier)
            let metadataTime = CFAbsoluteTimeGetCurrent() - metadataStartTime
            Logger.network.info("Fetched metadata in \(metadataTime.formatted(.number.precision(.fractionLength(4)))) seconds")
            
            // Find MP4 file
            let mp4Files = await archiveService.findPlayableFiles(in: metadata)
            
            guard let mp4File = mp4Files.first else {
                let error = "No MP4 file found in the archive"
                Logger.metadata.error("\(error)")
                throw NSError(domain: "VideoPlayerError", code: 1, userInfo: [NSLocalizedDescriptionKey: error])
            }
            
            guard let videoURL = await archiveService.getFileDownloadURL(for: mp4File, identifier: randomIdentifier) else {
                let error = "Could not create video URL"
                Logger.metadata.error("\(error)")
                throw NSError(domain: "VideoPlayerError", code: 2, userInfo: [NSLocalizedDescriptionKey: error])
            }
            
            // Create asset with optimized loading
            let assetStartTime = CFAbsoluteTimeGetCurrent()
            let asset = AVURLAsset(url: videoURL)
            Logger.videoPlayback.debug("Created AVURLAsset")
            
            // Set title and description from metadata
            self.currentTitle = metadata.metadata?.title ?? randomIdentifier
            self.currentDescription = metadata.metadata?.description ?? "Internet Archive random video clip"
            
            // Setup player with the asset
            playbackManager.setupPlayer(with: asset)
            
            // Get estimated duration from metadata
            let estimatedDuration = await archiveService.estimateDuration(fromFile: mp4File)
            
            let assetTime = CFAbsoluteTimeGetCurrent() - assetStartTime
            Logger.videoPlayback.info("Asset setup completed in \(assetTime.formatted(.number.precision(.fractionLength(4)))) seconds")
            
            self.isLoading = false
            
            // Play a random clip based on estimated duration
            await playRandomClip(estimatedDuration: estimatedDuration)
            
            let overallTime = CFAbsoluteTimeGetCurrent() - overallStartTime
            Logger.videoPlayback.info("Total video load time: \(overallTime.formatted(.number.precision(.fractionLength(4)))) seconds")
            
            // Start preloading the next videos
            await ensureVideosAreCached()
        } catch {
            Logger.videoPlayback.error("Failed to load video: \(error.localizedDescription)")
            isLoading = false
            errorMessage = "Error loading video: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Playback Control
    
    private func playRandomClip(estimatedDuration: Double) async {
        guard let playerItem = playbackManager.player?.currentItem else {
            Logger.videoPlayback.error("Cannot play clip - player item invalid")
            return
        }
        
        // Use more conservative duration to avoid seeking too close to the end
        let safetyMargin = min(estimatedDuration * 0.2, 60.0)
        let maxStartTime = max(0, estimatedDuration - safetyMargin)
        let safeMaxStartTime = max(0, min(maxStartTime, estimatedDuration - 40))
        
        // If video is very short, start from beginning
        let randomStart = safeMaxStartTime > 10 ? Double.random(in: 0..<safeMaxStartTime) : 0
        
        Logger.videoPlayback.info("Playing clip - selected random start position: \(randomStart.formatted(.number.precision(.fractionLength(2)))) seconds")
        
        let startTime = CMTime(seconds: randomStart, preferredTimescale: 600)
        
        // Wait for player item to be ready with its asset
        Logger.videoPlayback.debug("Waiting for player item to load duration...")
        
        // Load duration from asset
        do {
            _ = try await playerItem.asset.load(.duration)
            
            // Seek to the starting position with tolerance for faster seeking
            let seekStartTime = CFAbsoluteTimeGetCurrent()
            
            // Use a more tolerant seek for faster positioning
            playbackManager.seek(to: startTime) { [weak self] finished in
                let seekTime = CFAbsoluteTimeGetCurrent() - seekStartTime
                
                if finished {
                    Logger.videoPlayback.info("Seek completed in \(seekTime.formatted(.number.precision(.fractionLength(4)))) seconds")
                    
                    // Wait briefly for buffering before playing
                    Task { @MainActor in
                        // Give player a moment to buffer content
                        Logger.videoPlayback.debug("Waiting for buffer before starting playback...")
                        try? await Task.sleep(for: .seconds(0.5))
                        
                        // Play
                        self?.playbackManager.play()
                        
                        // Monitor buffer status after playback starts
                        if let playerItem = self?.playbackManager.player?.currentItem {
                            Task {
                                await self?.playbackManager.monitorBufferStatus(for: playerItem)
                            }
                        }
                    }
                } else {
                    Logger.videoPlayback.error("Seek failed after \(seekTime.formatted(.number.precision(.fractionLength(4)))) seconds")
                    
                    // Just play from current position
                    self?.playbackManager.play()
                }
            }
        } catch {
            Logger.videoPlayback.error("Failed to load asset duration: \(error.localizedDescription)")
            
            // Just play from the beginning
            playbackManager.play()
        }
    }
    
    // MARK: - Caching
    
    private func ensureVideosAreCached() async {
        await preloadService.ensureVideosAreCached(
            cacheManager: cacheManager,
            archiveService: archiveService,
            identifiers: identifiers
        )
    }
    
    deinit {
        // Cancel any ongoing tasks
        Task {
            await preloadService.cancelPreloading()
            await cacheManager.clearCache()
        }
        
        // Player cleanup is handled by playbackManager
        playbackManager.cleanupPlayer()
    }
}