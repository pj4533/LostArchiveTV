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
    @Published var player: AVPlayer?
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var videoDuration: Double = 0
    
    private var timeObserverToken: Any?
    
    // Current video URL for trimming
    private var _currentVideoURL: URL?
    
    // Computed properties for video trimming
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
    
    
    func useExistingPlayer(_ player: AVPlayer) {
        Logger.videoPlayback.debug("Using existing player (preserving seek position)")
        
        // Clean up resources from the existing player
        cleanupPlayer()
        
        // Use the provided player directly
        self.player = player
        
        // Extract and store the asset URL if it's an AVURLAsset
        if let asset = player.currentItem?.asset as? AVURLAsset {
            Logger.videoPlayback.debug("Extracted URL from asset: \(asset.url)")
            _currentVideoURL = asset.url
        } else {
            Logger.videoPlayback.warning("Could not extract URL from player asset")
        }
        
        // Set playback rate to 1 (normal speed)
        self.player?.rate = 1.0
        
        // Add time observer
        setupTimeObserver()
        
        // Add notification for playback ending if there's a current item
        if let playerItem = player.currentItem {
            setupPlaybackEndNotification(for: playerItem)
        }
        
        // Get current playback position for logging
        if let currentTime = player.currentItem?.currentTime().seconds,
           let duration = player.currentItem?.duration.seconds {
            Logger.videoPlayback.info("Using player at position \(currentTime.formatted(.number.precision(.fractionLength(2))))s of \(duration.formatted(.number.precision(.fractionLength(2))))s")
        }
    }
    
    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds
            
            // Update player state
            self.isPlaying = (self.player?.rate ?? 0) > 0
            
            // Update duration if needed
            if self.videoDuration == 0, let currentItem = self.player?.currentItem {
                let itemDuration = currentItem.duration
                if itemDuration.isValid && !itemDuration.isIndefinite {
                    self.videoDuration = itemDuration.seconds
                }
            }
        }
    }
    
    private func setupPlaybackEndNotification(for playerItem: AVPlayerItem) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
    }
    
    @objc private func playerItemDidReachEnd(notification: Notification) {
        Logger.videoPlayback.info("Video playback reached end")
        isPlaying = false
    }
    
    func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            Logger.videoPlayback.info("Audio session configured successfully")
        } catch {
            Logger.videoPlayback.error("Failed to configure audio session: \(error.localizedDescription)")
        }
    }
    
    func play() {
        Logger.videoPlayback.debug("Playing video")
        player?.play()
        isPlaying = true
    }
    
    func pause() {
        Logger.videoPlayback.debug("Pausing video")
        player?.pause()
        isPlaying = false
    }
    
    func seek(to time: CMTime, completion: ((Bool) -> Void)? = nil) {
        Logger.videoPlayback.debug("Seeking to time: \(time.seconds)")
        player?.seek(to: time, toleranceBefore: CMTime(seconds: 5, preferredTimescale: 600), 
                   toleranceAfter: CMTime(seconds: 5, preferredTimescale: 600)) { finished in
            completion?(finished)
        }
    }
    
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
    
    
    func cleanupPlayer() {
        Logger.videoPlayback.debug("Cleaning up player resources")
        
        // Remove time observer
        if let timeObserverToken = timeObserverToken, let player = player {
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
        
        // Remove notification observers
        NotificationCenter.default.removeObserver(
            self,
            name: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem
        )
        
        // Stop and clear player
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        isPlaying = false
        currentTime = 0
        videoDuration = 0
        _currentVideoURL = nil
    }
}