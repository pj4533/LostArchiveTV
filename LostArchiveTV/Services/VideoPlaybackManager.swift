//
//  VideoPlaybackManager.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import Foundation
import AVFoundation
import OSLog

class VideoPlaybackManager: ObservableObject {
    // MARK: - Published Properties
    @Published var player: AVPlayer?
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var videoDuration: Double = 0
    
    // MARK: - Internal Properties
    internal var timeObserverToken: Any?
    internal var _currentVideoURL: URL?
    internal let audioSessionManager = AudioSessionManager()
    internal var normalPlaybackRate: Float = 1.0
    
    // MARK: - Computed Properties
    var currentVideoURL: URL? {
        return _currentVideoURL
    }
    
    var currentTimeAsCMTime: CMTime? {
        guard let player = player else { return nil }
        return player.currentItem?.currentTime()
    }
    
    var durationAsCMTime: CMTime? {
        guard let player = player else { return nil }
        return player.currentItem?.duration
    }
    
    // MARK: - Initialization
    init() {
        Logger.videoPlayback.debug("VideoPlaybackManager initialized")
        // Configure audio session
        setupAudioSession()
    }
    
    // MARK: - Audio Session Management
    
    /// Configures the audio session for optimal playback
    func setupAudioSession(forTrimming: Bool = false) {
        if forTrimming {
            audioSessionManager.configureForTrimming()
        } else {
            audioSessionManager.configureForPlayback()
        }
    }
    
    /// Deactivates the audio session when done with playback
    func deactivateAudioSession() {
        audioSessionManager.deactivate()
    }
    
    // MARK: - Player Creation and Setup
    
    /// Uses an existing player instance instead of creating a new one
    func useExistingPlayer(_ player: AVPlayer) {
        let playerPointer = String(describing: ObjectIdentifier(player))
        Logger.videoPlayback.debug("🔄 PLAYER_CHANGE: Using existing player \(playerPointer) (preserving seek position)")

        // Log player item status before cleanup
        if let existingPlayer = self.player {
            let existingPointer = String(describing: ObjectIdentifier(existingPlayer))
            let existingItemStatus = existingPlayer.currentItem?.status.rawValue ?? -1
            Logger.videoPlayback.debug("🔄 PLAYER_CHANGE: About to clean up existing player \(existingPointer) with item status: \(existingItemStatus)")
        }

        // Clean up resources from the existing player
        cleanupPlayer()

        // Use the provided player directly
        self.player = player

        Logger.videoPlayback.debug("🔄 PLAYER_CHANGE: New player assigned \(String(describing: ObjectIdentifier(player))), current item: \(player.currentItem != nil ? "exists" : "nil")")

        // Extract and store the asset URL if it's an AVURLAsset
        if let asset = player.currentItem?.asset as? AVURLAsset {
            Logger.videoPlayback.debug("🔄 PLAYER_CHANGE: Extracted URL from asset: \(asset.url)")
            _currentVideoURL = asset.url
        } else {
            Logger.videoPlayback.warning("🔄 PLAYER_CHANGE: Could not extract URL from player asset")
        }

        // Set playback rate to 1 (normal speed)
        self.player?.rate = 1.0

        // Add time observer
        setupTimeObserver()

        // Add notification for playback ending if there's a current item
        if let playerItem = player.currentItem {
            setupPlaybackEndNotification(for: playerItem)
            Logger.videoPlayback.debug("🔄 PLAYER_CHANGE: Setup playback end notification for item status: \(playerItem.status.rawValue)")
        }

        // Get current playback position for logging
        if let currentTime = player.currentItem?.currentTime().seconds,
           let duration = player.currentItem?.duration.seconds {
            Logger.videoPlayback.info("🔄 PLAYER_CHANGE: Using player at position \(currentTime.formatted(.number.precision(.fractionLength(2))))s of \(duration.formatted(.number.precision(.fractionLength(2))))s")
        }
    }
    
    /// Creates a new player instance from an asset and URL
    func createNewPlayer(from asset: AVAsset, url: URL? = nil, startPosition: Double = 0) {
        let assetId = String(describing: ObjectIdentifier(asset))
        Logger.videoPlayback.debug("🆕 PLAYER_CREATE: Creating new player from asset \(assetId)")

        // Log player item status before cleanup
        if let existingPlayer = self.player {
            let existingPointer = String(describing: ObjectIdentifier(existingPlayer))
            let existingItemStatus = existingPlayer.currentItem?.status.rawValue ?? -1
            Logger.videoPlayback.debug("🆕 PLAYER_CREATE: About to clean up existing player \(existingPointer) with item status: \(existingItemStatus)")
        }

        // Clean up resources from the existing player
        cleanupPlayer()

        // Create a new player
        let playerItem = AVPlayerItem(asset: asset)
        Logger.videoPlayback.debug("🆕 PLAYER_CREATE: Created player item with asset \(assetId), item status: \(playerItem.status.rawValue)")

        self.player = AVPlayer(playerItem: playerItem)

        if let newPlayer = self.player {
            let newPointer = String(describing: ObjectIdentifier(newPlayer))
            Logger.videoPlayback.debug("🆕 PLAYER_CREATE: New player created with ID \(newPointer)")
        }

        // Store the URL if provided
        if let url = url {
            Logger.videoPlayback.debug("🆕 PLAYER_CREATE: Using provided URL: \(url.lastPathComponent)")
            _currentVideoURL = url
        } else if let urlAsset = asset as? AVURLAsset {
            Logger.videoPlayback.debug("🆕 PLAYER_CREATE: Extracted URL from asset: \(urlAsset.url.lastPathComponent)")
            _currentVideoURL = urlAsset.url
        }
        
        // Apply format-specific optimizations
        applyFormatSpecificOptimizations(for: asset)
        
        // Set up time observer
        setupTimeObserver()
        
        // Add notification for playback ending
        setupPlaybackEndNotification(for: playerItem)
        
        // Seek to start position if not zero
        if startPosition > 0 {
            let startTime = CMTime(seconds: startPosition, preferredTimescale: 600)
            player?.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }
    
    private func applyFormatSpecificOptimizations(for asset: AVAsset) {
        // Detect the format from URL if possible
        var fileFormat = "unknown"
        var isH264 = false
        var isH264IA = false
        
        if let urlAsset = asset as? AVURLAsset {
            // Try to extract format from URL path components
            let urlPath = urlAsset.url.path.lowercased()
            
            // Update format information for logging
            if urlPath.contains("h.264") && urlPath.contains("ia") {
                fileFormat = "h.264 IA"
                isH264 = true
                isH264IA = true
            } else if urlPath.contains("h.264") || urlPath.contains("h264") {
                fileFormat = "h.264"
                isH264 = true
            } else {
                fileFormat = "MPEG4"
            }
            
            Logger.videoPlayback.info("Player setup with format-specific optimizations for: \(fileFormat)")
        }
        
        // Apply format-specific player settings
        if isH264IA {
            // h.264 IA specific player optimizations
            Logger.videoPlayback.debug("Applying h.264 IA specific player settings")
            // For h.264 IA, we can disable waiting to minimize stalling since it's optimized for streaming
            player?.automaticallyWaitsToMinimizeStalling = false
        } else if isH264 {
            // Regular h.264 optimizations - keep auto stalling for smoother playback
            Logger.videoPlayback.debug("Applying regular h.264 player settings")
            player?.automaticallyWaitsToMinimizeStalling = true
        } else {
            // MPEG4 - definitely need auto stalling
            Logger.videoPlayback.debug("Applying MPEG4 player settings")
            player?.automaticallyWaitsToMinimizeStalling = true
        }
    }
    
    // MARK: - Playback Control
    
    /// Starts or resumes playback
    func play() {
        if let player = player {
            let playerPointer = String(describing: ObjectIdentifier(player))
            let itemStatus = player.currentItem?.status.rawValue ?? -1
            Logger.videoPlayback.debug("▶️ VP_MANAGER: Play requested for player \(playerPointer), item status: \(itemStatus)")
        } else {
            Logger.videoPlayback.warning("▶️ VP_MANAGER: Play requested but player is nil")
        }
        Logger.videoPlayback.debug("Playing video")
        player?.play()
        isPlaying = true
    }
    
    /// Pauses playback
    func pause() {
        if let player = player {
            let playerPointer = String(describing: ObjectIdentifier(player))
            let itemStatus = player.currentItem?.status.rawValue ?? -1
            Logger.videoPlayback.debug("⏸️ VP_MANAGER: Pause requested for player \(playerPointer), item status: \(itemStatus)")
        } else {
            Logger.videoPlayback.warning("⏸️ VP_MANAGER: Pause requested but player is nil")
        }
        Logger.videoPlayback.debug("Pausing video")
        player?.pause()
        isPlaying = false
    }
    
    /// Seeks to a specific time in the video
    func seek(to time: CMTime, completion: ((Bool) -> Void)? = nil) {
        Logger.videoPlayback.debug("Seeking to time: \(time.seconds)")
        player?.seek(to: time, toleranceBefore: CMTime(seconds: 0.1, preferredTimescale: 600), 
                   toleranceAfter: CMTime(seconds: 0.1, preferredTimescale: 600)) { finished in
            completion?(finished)
        }
    }
    
    /// Seeks to the beginning of the video and starts playback
    func seekToBeginning() {
        Logger.videoPlayback.info("Seeking to beginning of video and playing")
        player?.seek(to: CMTime.zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] completed in
            if completed {
                self?.player?.play()
                self?.isPlaying = true
            }
        }
    }
    
    /// Sets a temporary playback rate, storing the current rate for later restoration
    func setTemporaryPlaybackRate(rate: Float) {
        Logger.videoPlayback.debug("Setting temporary playback rate to \(rate)")
        guard let player = player else { return }
        
        // Store the current rate before changing it (if we haven't already)
        if normalPlaybackRate == 1.0 && player.rate != rate {
            normalPlaybackRate = player.rate > 0 ? player.rate : 1.0
        }
        
        // Set the new playback rate
        player.rate = rate
    }
    
    /// Resets the playback rate to the previously stored normal rate
    func resetPlaybackRate() {
        Logger.videoPlayback.debug("Resetting playback rate to \(self.normalPlaybackRate)")
        guard let player = player else { return }
        
        // Only reset if we're not already at the normal rate
        if player.rate != self.normalPlaybackRate {
            player.rate = self.normalPlaybackRate
        }
        
        // Reset the stored normal rate
        self.normalPlaybackRate = 1.0
    }
    
    // MARK: - Monitoring and Observation
    
    /// Sets up periodic time observation for the player
    internal func setupTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds

            // Update player state
            self.isPlaying = (self.player?.rate ?? 0) > 0

            // Always check and update duration to make sure it's current
            if let currentItem = self.player?.currentItem {
                let itemDuration = currentItem.duration
                if itemDuration.isValid && !itemDuration.isIndefinite {
                    self.videoDuration = itemDuration.seconds
                }
            }

            // No trim boundary handling needed in main player - VideoTrimView handles this internally
        }
    }
    
    /// Sets up notification for when playback reaches the end
    internal func setupPlaybackEndNotification(for playerItem: AVPlayerItem) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
    }
    
    /// Handler for when playback reaches the end
    @objc private func playerItemDidReachEnd(notification: Notification) {
        Logger.videoPlayback.info("Video playback reached end - restarting from beginning")
        // Seek to the beginning and continue playing
        player?.seek(to: CMTime.zero)
        player?.play()
        isPlaying = true
    }
    
    /// Monitors buffer status for the given player item
    func monitorBufferStatus(for playerItem: AVPlayerItem) async {
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
                    [Monitor \(monitorCount+1)/10] Playback status at time \(currentTime.formatted(.number.precision(.fractionLength(2))))s / \(totalDuration.formatted(.number.precision(.fractionLength(2))))s (\(percentComplete.formatted(.number.precision(.fractionLength(2)))))%):
                    - Buffered: \(bufferedDuration.formatted(.number.precision(.fractionLength(1))))s ahead
                    - Buffer status: \(bufferEmpty ? "EMPTY" : bufferFull ? "FULL" : playbackLikelyToKeepUp ? "GOOD" : "LOW")
                    - Buffer likely to keep up: \(playbackLikelyToKeepUp)
                    - Buffer full: \(bufferFull)
                    - Buffer empty: \(bufferEmpty)
                    """
                    
                    Logger.videoPlayback.debug("\(monitorLog)")
                    
                    if bufferEmpty {
                        Logger.videoPlayback.warning("⚠️ Playback buffer empty at \(currentTime.formatted(.number.precision(.fractionLength(2))))s (\(percentComplete.formatted(.number.precision(.fractionLength(2)))))%)")
                    }
                }
                
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }
    
    // MARK: - Cleanup
    
    /// Cleans up all player resources
    func cleanupPlayer() {
        // Get player identifier for logging before cleanup
        var playerPointerStr = "nil"
        var playerItemStatus = -1
        if let existingPlayer = player {
            playerPointerStr = String(describing: ObjectIdentifier(existingPlayer))
            playerItemStatus = existingPlayer.currentItem?.status.rawValue ?? -1
        }

        Logger.videoPlayback.debug("🧹 PLAYER_CLEANUP: Starting cleanup for player \(playerPointerStr), item status: \(playerItemStatus)")

        // Remove time observer
        if let timeObserverToken = timeObserverToken, let player = player {
            Logger.videoPlayback.debug("🧹 PLAYER_CLEANUP: Removing time observer")
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }

        // Remove notification observers
        if let currentItem = player?.currentItem {
            Logger.videoPlayback.debug("🧹 PLAYER_CLEANUP: Removing notification observers for item with status: \(currentItem.status.rawValue)")
            NotificationCenter.default.removeObserver(
                self,
                name: .AVPlayerItemDidPlayToEndTime,
                object: currentItem
            )
        }

        // Log URL before clearing
        if let url = _currentVideoURL {
            Logger.videoPlayback.debug("🧹 PLAYER_CLEANUP: Clearing URL: \(url.lastPathComponent)")
        }

        // Stop and clear player
        Logger.videoPlayback.debug("🧹 PLAYER_CLEANUP: Pausing and replacing player item with nil")
        player?.pause()
        player?.replaceCurrentItem(with: nil)

        Logger.videoPlayback.debug("🧹 PLAYER_CLEANUP: Setting player to nil and resetting state")
        player = nil
        isPlaying = false
        currentTime = 0
        videoDuration = 0
        _currentVideoURL = nil

        Logger.videoPlayback.debug("🧹 PLAYER_CLEANUP: Cleanup complete")
    }
}