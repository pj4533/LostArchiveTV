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
    
    /// Sets up status observation for the given player item to detect content failures
    internal func setupPlayerItemStatusObservation(for playerItem: AVPlayerItem) {
        // Observe the status property
        playerItem.publisher(for: \.status)
            .sink { [weak self] status in
                guard let self = self else { return }
                
                switch status {
                case .failed:
                    if let error = playerItem.error {
                        Logger.videoPlayback.error("🚫 VP_MANAGER: Player item failed with error: \(error.localizedDescription)")
                        
                        // Check if this is an unrecoverable content error
                        if self.isUnrecoverableContentError(error) {
                            self.handleContentFailureSilently(error: error)
                        }
                    }
                case .readyToPlay:
                    Logger.videoPlayback.debug("✅ VP_MANAGER: Player item ready to play")
                case .unknown:
                    Logger.videoPlayback.debug("❓ VP_MANAGER: Player item status unknown")
                @unknown default:
                    Logger.videoPlayback.debug("❓ VP_MANAGER: Player item has unknown status: \(status.rawValue)")
                }
            }
            .store(in: &statusObservations)
        
        // Also observe for error log entries
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemNewErrorLogEntry),
            name: .AVPlayerItemNewErrorLogEntry,
            object: playerItem
        )
        
        // Observe for playback stalls that might indicate content issues
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemPlaybackStalled),
            name: .AVPlayerItemPlaybackStalled,
            object: playerItem
        )
        
        // Observe for failed to play to end time
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemFailedToPlayToEndTime),
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem
        )
    }
    
    /// Handler for new error log entries
    @objc private func playerItemNewErrorLogEntry(notification: Notification) {
        guard let playerItem = notification.object as? AVPlayerItem,
              let errorLog = playerItem.errorLog() else { return }
        
        for event in errorLog.events {
            Logger.videoPlayback.error("🚫 VP_MANAGER: Error log entry - Domain: \(event.errorDomain ?? "unknown"), Code: \(event.errorStatusCode), Comment: \(event.errorComment ?? "none")")
        }
    }
    
    /// Handler for playback stalls
    @objc private func playerItemPlaybackStalled(notification: Notification) {
        Logger.videoPlayback.warning("⚠️ VP_MANAGER: Playback stalled")
        
        // Check if the player item has failed
        if let playerItem = notification.object as? AVPlayerItem,
           playerItem.status == .failed,
           let error = playerItem.error {
            if isUnrecoverableContentError(error) {
                handleContentFailureSilently(error: error)
            }
        }
    }
    
    /// Handler for failed to play to end time
    @objc private func playerItemFailedToPlayToEndTime(notification: Notification) {
        Logger.videoPlayback.error("🚫 VP_MANAGER: Failed to play to end time")
        
        if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
            if isUnrecoverableContentError(error) {
                handleContentFailureSilently(error: error)
            }
        }
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