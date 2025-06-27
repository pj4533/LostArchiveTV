//
//  VideoPlaybackManager+Monitoring.swift
//  LostArchiveTV
//
//  Created by VideoPlaybackManager split on 6/27/25.
//

import Foundation
import AVFoundation
import OSLog

// MARK: - Monitoring and Observation
extension VideoPlaybackManager {
    
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
        Logger.videoPlayback.info("🔄 VP_MANAGER: Video playback reached end - restarting from beginning")
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
                    📊 VP_MANAGER: [Monitor \(monitorCount+1)/10] Playback status at time \(currentTime.formatted(.number.precision(.fractionLength(2))))s / \(totalDuration.formatted(.number.precision(.fractionLength(2))))s (\(percentComplete.formatted(.number.precision(.fractionLength(2)))))%):
                    - Buffered: \(bufferedDuration.formatted(.number.precision(.fractionLength(1))))s ahead
                    - Buffer status: \(bufferEmpty ? "EMPTY" : bufferFull ? "FULL" : playbackLikelyToKeepUp ? "GOOD" : "LOW")
                    - Buffer likely to keep up: \(playbackLikelyToKeepUp)
                    - Buffer full: \(bufferFull)
                    - Buffer empty: \(bufferEmpty)
                    """
                    
                    Logger.videoPlayback.debug("\(monitorLog)")
                    
                    if bufferEmpty {
                        Logger.videoPlayback.warning("⚠️ VP_MANAGER: Playback buffer empty at \(currentTime.formatted(.number.precision(.fractionLength(2))))s (\(percentComplete.formatted(.number.precision(.fractionLength(2)))))%)")
                    }
                }
                
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }
}