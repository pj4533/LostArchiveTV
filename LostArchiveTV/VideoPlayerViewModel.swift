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

// MARK: - Loggers
extension Logger {
    static let videoPlayback = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "videoPlayback")
    static let network = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "network")
    static let metadata = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "metadata")
    static let caching = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "caching")
}

// MARK: - Main ViewModel Class
@MainActor
class VideoPlayerViewModel: ObservableObject {
    // Archive.org video identifiers
    private lazy var identifiers: [String] = {
        loadArchiveIdentifiers()
    }()
    
    // Caching for video preloading
    private var cachedVideos: [CachedVideo] = []
    private var preloadTask: Task<Void, Never>?
    private let maxCachedVideos = 3 // Increased for smoother swiping experience
    
    // Published properties
    @Published var player: AVPlayer?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var videoDuration: Double = 0
    @Published var currentIdentifier: String?
    @Published var currentTitle: String?
    @Published var currentDescription: String?
    
    // MARK: - Initialization and Cleanup
    init() {
        // Configure audio session for proper playback on all devices
        setupAudioSession()
        
        // Start preloading videos when the ViewModel is initialized
        Task {
            // Brief delay to allow app to initialize fully
            try? await Task.sleep(for: .seconds(0.5))
            ensureVideosAreCached()
        }
        
        // Configure logging
        Logger.videoPlayback.info("TikTok-style video player initialized with swipe interface")
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            Logger.videoPlayback.info("Audio session configured successfully")
        } catch {
            Logger.videoPlayback.error("Failed to configure audio session: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Swipe Interface Support
    
    /// Prepares the player for swiping by ensuring multiple videos are cached
    func prepareForSwipe() {
        Logger.videoPlayback.debug("Preparing for swipe interactions")
        ensureVideosAreCached()
    }
    
    /// Handles the completion of a swipe gesture
    func handleSwipeCompletion() {
        Logger.videoPlayback.info("Swipe gesture completed, loading next video")
        Task {
            await loadRandomVideo()
        }
    }
    
    deinit {
        // Cancel any ongoing tasks
        preloadTask?.cancel()
        
        // Note: Cannot access MainActor-isolated properties in deinit
        // Player cleanup is handled by ARC
        
        // Clear cached videos (non-actor-isolated)
        cachedVideos.removeAll()
    }
}

// MARK: - Metadata Loading
extension VideoPlayerViewModel {
    // Load all identifiers from the bundled JSON file
    private func loadArchiveIdentifiers() -> [String] {
        Logger.metadata.debug("Loading archive identifiers from bundle")
        guard let url = Bundle.main.url(forResource: "avgeeks_identifiers", withExtension: "json") else {
            Logger.metadata.error("Failed to find identifiers file")
            return []
        }
        
        do {
            let startTime = CFAbsoluteTimeGetCurrent()
            let data = try Data(contentsOf: url)
            let identifierObjects = try JSONDecoder().decode([ArchiveIdentifier].self, from: data)
            let identifiers = identifierObjects.map { $0.identifier }
            let loadTime = CFAbsoluteTimeGetCurrent() - startTime
            Logger.metadata.info("Loaded \(identifiers.count) identifiers in \(loadTime.formatted(.number.precision(.fractionLength(4)))) seconds")
            return identifiers
        } catch {
            Logger.metadata.error("Failed to decode identifiers: \(error.localizedDescription)")
            return []
        }
    }
    
    private func fetchMetadata(for identifier: String) async throws -> ArchiveMetadata {
        let metadataURL = URL(string: "https://archive.org/metadata/\(identifier)")!
        Logger.network.debug("Fetching metadata from: \(metadataURL)")
        
        // Create URLSession configuration with cache
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        let session = URLSession(configuration: config)
        
        let requestStartTime = CFAbsoluteTimeGetCurrent()
        let (data, response) = try await session.data(from: metadataURL)
        let requestTime = CFAbsoluteTimeGetCurrent() - requestStartTime
        
        if let httpResponse = response as? HTTPURLResponse {
            Logger.network.debug("Metadata response: HTTP \(httpResponse.statusCode), size: \(data.count) bytes, time: \(requestTime.formatted(.number.precision(.fractionLength(4)))) seconds")
        }
        
        let decodingStartTime = CFAbsoluteTimeGetCurrent()
        let metadata = try JSONDecoder().decode(ArchiveMetadata.self, from: data)
        let decodingTime = CFAbsoluteTimeGetCurrent() - decodingStartTime
        
        Logger.metadata.debug("Decoded metadata with \(metadata.files.count) files in \(decodingTime.formatted(.number.precision(.fractionLength(4)))) seconds")
        return metadata
    }
}

// MARK: - Video Loading and Playback
extension VideoPlayerViewModel {
    func loadRandomVideo() async {
        let overallStartTime = CFAbsoluteTimeGetCurrent()
        Logger.videoPlayback.info("Starting to load random video for swipe interface")
        isLoading = true
        errorMessage = nil
        
        // Clean up existing player
        if let existingPlayer = player {
            Logger.videoPlayback.debug("Cleaning up existing player for swipe transition")
            existingPlayer.pause()
            existingPlayer.replaceCurrentItem(with: nil)
            player = nil
        }
        
        // Pre-emptively start caching next videos for smooth swipes
        Task {
            ensureVideosAreCached()
        }
        
        // Check if we have cached videos available
        if let cachedVideo = cachedVideos.first {
            Logger.videoPlayback.info("Using cached video: \(cachedVideo.identifier)")
            
            // Use the cached video
            currentIdentifier = cachedVideo.identifier
            currentTitle = cachedVideo.title
            currentDescription = cachedVideo.description
            player = cachedVideo.player
            videoDuration = estimateDuration(fromFile: cachedVideo.mp4File)
            
            // Remove the used cached video
            cachedVideos.removeFirst()
            
            // Start playback at the predetermined position
            let startPosition = cachedVideo.startPosition
            let startTime = CMTime(seconds: startPosition, preferredTimescale: 600)
            Logger.videoPlayback.info("Starting playback at time offset: \(startPosition.formatted(.number.precision(.fractionLength(2)))) / \(self.videoDuration.formatted(.number.precision(.fractionLength(2)))) seconds (\((startPosition/self.videoDuration * 100).formatted(.number.precision(.fractionLength(2))))%)")
            
            let seekStartTime = CFAbsoluteTimeGetCurrent()
            await player?.seek(to: startTime)
            let seekTime = CFAbsoluteTimeGetCurrent() - seekStartTime
            Logger.videoPlayback.info("Cached video seek completed in \(seekTime.formatted(.number.precision(.fractionLength(4)))) seconds")
            
            // Start playback
            player?.play()
            
            // Play continuously (no auto-pause)
            Logger.videoPlayback.info("Playing continuously until user requests another clip")
            
            isLoading = false
            
            // Start preloading the next video if needed
            ensureVideosAreCached()
            
            let overallTime = CFAbsoluteTimeGetCurrent() - overallStartTime
            Logger.videoPlayback.info("Total cached video load time: \(overallTime.formatted(.number.precision(.fractionLength(4)))) seconds")
            return
        }
        
        // No cached videos available, load a random one
        guard let randomIdentifier = identifiers.randomElement() else {
            Logger.metadata.error("No identifiers available")
            errorMessage = "No identifiers available. Make sure avgeeks_identifiers.json is in the app bundle."
            isLoading = false
            return
        }
        
        currentIdentifier = randomIdentifier
        Logger.metadata.info("Selected random video: \(randomIdentifier)")
        
        do {
            let metadataStartTime = CFAbsoluteTimeGetCurrent()
            let metadata = try await fetchMetadata(for: randomIdentifier)
            let metadataTime = CFAbsoluteTimeGetCurrent() - metadataStartTime
            Logger.network.info("Fetched metadata in \(metadataTime.formatted(.number.precision(.fractionLength(4)))) seconds")
            
            let playerSetupStartTime = CFAbsoluteTimeGetCurrent()
            try await setupVideoPlayer(metadata: metadata)
            let playerSetupTime = CFAbsoluteTimeGetCurrent() - playerSetupStartTime
            Logger.videoPlayback.info("Set up video player in \(playerSetupTime.formatted(.number.precision(.fractionLength(4)))) seconds")
            
            let overallTime = CFAbsoluteTimeGetCurrent() - overallStartTime
            Logger.videoPlayback.info("Total video load time: \(overallTime.formatted(.number.precision(.fractionLength(4)))) seconds")
            
            // Start preloading the next videos
            ensureVideosAreCached()
        } catch {
            Logger.videoPlayback.error("Failed to load video: \(error.localizedDescription)")
            isLoading = false
            errorMessage = "Error loading video: \(error.localizedDescription)"
        }
    }
    
    private func setupVideoPlayer(metadata: ArchiveMetadata) async throws {
        let setupStartTime = CFAbsoluteTimeGetCurrent()
        Logger.videoPlayback.debug("Setting up video player from metadata")
        
        // Look for the main MP4 file
        let filterStartTime = CFAbsoluteTimeGetCurrent()
        let mp4Files = metadata.files.filter { $0.format == "MPEG4" || ($0.name.hasSuffix(".mp4")) }
        let filterTime = CFAbsoluteTimeGetCurrent() - filterStartTime
        Logger.metadata.debug("Found \(mp4Files.count) MP4 files in \(filterTime.formatted(.number.precision(.fractionLength(4)))) seconds")
        
        guard let mp4File = mp4Files.first else {
            let error = "No MP4 file found in the archive"
            Logger.metadata.error("\(error)")
            throw NSError(domain: "VideoPlayerError", code: 1, userInfo: [NSLocalizedDescriptionKey: error])
        }
        
        guard let identifier = currentIdentifier else {
            let error = "No identifier selected"
            Logger.videoPlayback.error("\(error)")
            throw NSError(domain: "VideoPlayerError", code: 3, userInfo: [NSLocalizedDescriptionKey: error])
        }
        
        let videoURL = URL(string: "https://archive.org/download/\(identifier)/\(mp4File.name)")!
        Logger.network.info("Video file URL: \(videoURL)")
        
        // Get estimated duration from metadata
        self.videoDuration = estimateDuration(fromFile: mp4File)
        
        // Set title and description from metadata
        self.currentTitle = metadata.metadata?.title ?? identifier
        self.currentDescription = metadata.metadata?.description ?? "Internet Archive random video clip"
        
        // Create asset with optimized loading
        let assetStartTime = CFAbsoluteTimeGetCurrent()
        let asset = AVURLAsset(url: videoURL)
        Logger.videoPlayback.debug("Created AVURLAsset")
        
        // Configure for streaming
        let playerItem = AVPlayerItem(asset: asset)
        
        // Set preferred forward buffer duration to minimize loading but ensure smooth playback
        playerItem.preferredForwardBufferDuration = 60 // Buffer 60 seconds ahead at most
        Logger.videoPlayback.debug("Configured player item with 60s forward buffer")
        
        // Create a new player
        self.player = AVPlayer(playerItem: playerItem)
        
        // Set playback rate to 1 (normal speed)
        self.player?.rate = 1.0
        let assetTime = CFAbsoluteTimeGetCurrent() - assetStartTime
        Logger.videoPlayback.info("Asset setup completed in \(assetTime.formatted(.number.precision(.fractionLength(4)))) seconds")
        
        self.isLoading = false
        
        let totalSetupTime = CFAbsoluteTimeGetCurrent() - setupStartTime
        Logger.videoPlayback.info("Video player setup completed in \(totalSetupTime.formatted(.number.precision(.fractionLength(4)))) seconds")
        
        // Play a random clip based on estimated duration
        playRandomClip()
    }
}

// MARK: - Playback Control and Monitoring
extension VideoPlayerViewModel {
    func playRandomClip() {
        Logger.videoPlayback.debug("Starting to play random clip")
        guard let player = player, let playerItem = player.currentItem else {
            Logger.videoPlayback.error("Cannot play clip - player or player item invalid")
            return 
        }
        
        // Get a more accurate duration from the player item if available
        Task { @MainActor in
            // Wait for player item to be ready with its asset
            Logger.videoPlayback.debug("Waiting for player item to load duration...")
            
            // Load duration from asset
            await playerItem.asset.loadValues(forKeys: ["duration"])
            
            // Try to get a more accurate duration from the asset
            let assetDuration = playerItem.asset.duration.seconds
            if assetDuration > 0 && assetDuration.isFinite {
                Logger.videoPlayback.info("Got actual duration from asset: \(assetDuration.formatted(.number.precision(.fractionLength(2)))) seconds (previous estimate: \(self.videoDuration.formatted(.number.precision(.fractionLength(2)))))")
                videoDuration = assetDuration
            } else {
                Logger.videoPlayback.warning("Asset returned invalid duration: \(assetDuration), keeping metadata estimate")
            }
            
            // Now that we have the best possible duration, perform the seek
            performSeekAndPlay(player: player)
        }
    }
    
    // Separate function to perform seek and play after duration is determined
    private func performSeekAndPlay(player: AVPlayer) {
        guard let playerItem = player.currentItem, videoDuration > 0 else {
            Logger.videoPlayback.error("Cannot perform seek - player item or duration invalid")
            return
        }
        
        // Use more conservative duration - either 80% of total duration or total minus 60s, whichever is smaller
        // This helps avoid seeking too close to the end
        let safetyMargin = min(videoDuration * 0.2, 60.0)
        let maxStartTime = max(0, videoDuration - safetyMargin)
        
        // Add additional guard to ensure we don't pick a position too close to the end
        let safeMaxStartTime = max(0, min(maxStartTime, videoDuration - 40))
        
        // If video is very short, start from beginning
        let randomStart = safeMaxStartTime > 10 ? Double.random(in: 0..<safeMaxStartTime) : 0
        
        Logger.videoPlayback.info("Playing clip - safe start range: 0 to \(safeMaxStartTime.formatted(.number.precision(.fractionLength(2)))) seconds (of total \(self.videoDuration.formatted(.number.precision(.fractionLength(2)))))")
        Logger.videoPlayback.info("Selected random start position: \(randomStart.formatted(.number.precision(.fractionLength(2)))) seconds (\((randomStart/self.videoDuration * 100).formatted(.number.precision(.fractionLength(2))))% of total duration)")
        
        let startTime = CMTime(seconds: randomStart, preferredTimescale: 600)
        let seekStartTime = CFAbsoluteTimeGetCurrent()
        
        // Use a more tolerant seek - allow for approximate positioning
        player.seek(to: startTime, toleranceBefore: CMTime(seconds: 5, preferredTimescale: 600), 
                   toleranceAfter: CMTime(seconds: 5, preferredTimescale: 600)) { [weak self] finished in
            let seekTime = CFAbsoluteTimeGetCurrent() - seekStartTime
            
            if finished {
                Logger.videoPlayback.info("Seek completed in \(seekTime.formatted(.number.precision(.fractionLength(4)))) seconds")
                
                // Check if we're near the end
                let currentPosition = playerItem.currentTime().seconds
                // Use a safe approach for accessing actor-isolated property from closure
                let timeRemaining: Double
                if let strongSelf = self {
                    Task { @MainActor in
                        let duration = strongSelf.videoDuration
                        Logger.videoPlayback.debug("Current duration: \(duration), position: \(currentPosition)")
                    }
                }
                // For the check, we can use a more conservative estimate
                let conservativeDuration = 600.0 // 10 minutes as fallback
                timeRemaining = (self?.videoDuration ?? conservativeDuration) - currentPosition
                
                if timeRemaining < 10 {
                    // Too close to end, try again with a different position
                    Logger.videoPlayback.warning("Seek positioned too close to end (\(timeRemaining.formatted(.number.precision(.fractionLength(2)))) seconds remaining). Retrying...")
                    
                    // Must use Task to call MainActor-isolated method
                    Task { @MainActor [weak self] in  
                        self?.performSeekAndPlay(player: player)
                    }
                    return
                }
                
                // Wait briefly for buffering before playing
                Task { @MainActor in
                    // Give player a moment to buffer content
                    Logger.videoPlayback.debug("Waiting for buffer before starting playback...")
                    try? await Task.sleep(for: .seconds(0.5))
                    
                    // Play only if buffering is likely to keep up
                    if playerItem.isPlaybackLikelyToKeepUp {
                        Logger.videoPlayback.info("Buffer ready, starting playback")
                        player.play()
                        
                        // Monitor buffer status after playback starts
                        if let strongSelf = self {
                            Task {
                                await strongSelf.monitorBufferStatus(for: playerItem)
                            }
                        }
                        
                        // Play continuously (no auto-pause)
                        Logger.videoPlayback.info("Playing continuously until user requests another clip")
                    } else {
                        // Not enough buffer, try to play anyway but log the issue
                        Logger.videoPlayback.warning("Buffer not optimal but attempting playback anyway")
                        player.play()
                    }
                }
            } else {
                Logger.videoPlayback.error("Seek failed after \(seekTime.formatted(.number.precision(.fractionLength(4)))) seconds, trying again...")
                
                // Try one more time with a different position - must be done on the main actor
                Task { @MainActor [weak self] in
                    self?.performSeekAndPlay(player: player)
                }
            }
        }
    }
    
    // Monitor buffer status for playback performance analysis
    private func monitorBufferStatus(for playerItem: AVPlayerItem?) async {
        guard let playerItem = playerItem else { return }
        
        Task { @MainActor in
            for monitorCount in 0..<10 {
                guard self.player != nil else { break }
                
                let currentTime = playerItem.currentTime().seconds
                let totalDuration = self.videoDuration
                let percentComplete = totalDuration > 0 ? (currentTime / totalDuration) * 100 : 0
                let loadedRanges = playerItem.loadedTimeRanges
                
                if !loadedRanges.isEmpty {
                    let bufferedDuration = loadedRanges.reduce(0.0) { total, timeRange in
                        let range = timeRange.timeRangeValue
                        return total + range.duration.seconds
                    }
                    
                    let playbackLikelyToKeepUp = playerItem.isPlaybackLikelyToKeepUp
                    let bufferFull = playerItem.isPlaybackBufferFull
                    let bufferEmpty = playerItem.isPlaybackBufferEmpty
                    
                    // Create detailed playback progress log
                    let monitorLog = """
                    [Monitor \(monitorCount+1)/10] Playback status at time \(currentTime.formatted(.number.precision(.fractionLength(2))))s / \(totalDuration.formatted(.number.precision(.fractionLength(2))))s (\(percentComplete.formatted(.number.precision(.fractionLength(2))))%):
                    - Title: \(self.currentTitle ?? "Unknown")
                    - Buffered: \(bufferedDuration.formatted(.number.precision(.fractionLength(1))))s ahead
                    - Buffer status: \(bufferEmpty ? "EMPTY" : bufferFull ? "FULL" : playbackLikelyToKeepUp ? "GOOD" : "LOW")
                    - Buffer likely to keep up: \(playbackLikelyToKeepUp)
                    - Buffer full: \(bufferFull)
                    - Buffer empty: \(bufferEmpty)
                    """
                    
                    Logger.videoPlayback.debug("\(monitorLog)")
                    
                    if bufferEmpty {
                        Logger.videoPlayback.warning("⚠️ Playback buffer empty at \(currentTime.formatted(.number.precision(.fractionLength(2))))s (\(percentComplete.formatted(.number.precision(.fractionLength(2))))%)")
                    }
                }
                
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }
}

// MARK: - Caching Methods
extension VideoPlayerViewModel {
    private func estimateDuration(fromFile file: ArchiveFile) -> Double {
        var estimatedDuration: Double = 0
        
        if let lengthStr = file.length {
            Logger.metadata.debug("Found duration string in metadata: \(lengthStr)")
            
            // First, try to parse as a direct number of seconds (e.g., "1724.14")
            if let directSeconds = Double(lengthStr) {
                estimatedDuration = directSeconds
                Logger.metadata.debug("Parsed direct seconds value: \(estimatedDuration) seconds")
            }
            // If that fails, try to parse as HH:MM:SS format
            else if lengthStr.contains(":") {
                let components = lengthStr.components(separatedBy: ":")
                if components.count == 3, 
                   let hours = Double(components[0]),
                   let minutes = Double(components[1]),
                   let seconds = Double(components[2]) {
                    estimatedDuration = hours * 3600 + minutes * 60 + seconds
                    Logger.metadata.debug("Parsed HH:MM:SS format: \(estimatedDuration) seconds")
                }
            }
        }
        
        // Set a default approximate duration if we couldn't get one (30 minutes)
        if estimatedDuration <= 0 {
            estimatedDuration = 1800
            Logger.metadata.debug("Using default duration: \(estimatedDuration) seconds")
        } else {
            Logger.metadata.debug("Using extracted duration: \(estimatedDuration) seconds")
        }
        
        return estimatedDuration
    }
    
    private func ensureVideosAreCached() {
        // Cancel any existing preload task
        preloadTask?.cancel()
        
        // Start a new preload task
        preloadTask = Task {
            Logger.caching.info("Starting cache preload for swipe interface, current cache size: \(self.cachedVideos.count)")
            
            // Prioritize loading at least one video immediately
            if self.cachedVideos.isEmpty {
                Logger.caching.debug("Cache empty, prioritizing first video load")
                do {
                    try await self.preloadRandomVideo()
                } catch {
                    Logger.caching.error("Failed to preload first video: \(error.localizedDescription)")
                }
            }
            
            // Preload up to maxCachedVideos
            while !Task.isCancelled && self.cachedVideos.count < self.maxCachedVideos {
                do {
                    try await self.preloadRandomVideo()
                } catch {
                    Logger.caching.error("Failed to preload video: \(error.localizedDescription)")
                    // Give a short pause before trying again
                    try? await Task.sleep(for: .seconds(0.5)) // Reduced wait time for swipe interface
                }
            }
            
            Logger.caching.info("Cache preload for swipe interface completed, cache size: \(self.cachedVideos.count)")
        }
    }
    
    private func preloadRandomVideo() async throws {
        guard let randomIdentifier = identifiers.randomElement() else {
            Logger.caching.error("No identifiers available for preloading")
            throw NSError(domain: "PreloadError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No identifiers available"])
        }
        
        Logger.caching.info("Preloading random video: \(randomIdentifier)")
        
        // Fetch metadata
        let metadata = try await fetchMetadata(for: randomIdentifier)
        
        // Find MP4 file
        let mp4Files = metadata.files.filter { $0.format == "MPEG4" || ($0.name.hasSuffix(".mp4")) }
        
        guard let mp4File = mp4Files.first else {
            Logger.caching.error("No MP4 file found for \(randomIdentifier)")
            throw NSError(domain: "PreloadError", code: 2, userInfo: [NSLocalizedDescriptionKey: "No MP4 file found"])
        }
        
        // Create URL and asset
        let videoURL = URL(string: "https://archive.org/download/\(randomIdentifier)/\(mp4File.name)")!
        
        // Create optimized asset
        let asset = AVURLAsset(url: videoURL)
        
        // Create player item with caching configuration
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 60
        
        // Calculate a random start position
        let estimatedDuration = estimateDuration(fromFile: mp4File)
        let safetyMargin = min(estimatedDuration * 0.2, 60.0)
        let maxStartTime = max(0, estimatedDuration - safetyMargin)
        let safeMaxStartTime = max(0, min(maxStartTime, estimatedDuration - 40))
        let randomStart = safeMaxStartTime > 10 ? Double.random(in: 0..<safeMaxStartTime) : 0
        
        // Log the preloaded video's start position
        Logger.caching.info("Preloaded video start position: \(randomStart.formatted(.number.precision(.fractionLength(2)))) / \(estimatedDuration.formatted(.number.precision(.fractionLength(2)))) seconds (\((randomStart/estimatedDuration * 100).formatted(.number.precision(.fractionLength(2))))%)")
        
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
        
        // Start preloading the asset by requesting its duration (which loads data)
        _ = try await asset.load(.duration)
        
        // Store in the cache
        Logger.caching.info("Successfully preloaded video: \(randomIdentifier), adding to cache")
        cachedVideos.append(cachedVideo)
    }
}
