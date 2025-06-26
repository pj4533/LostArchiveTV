//
//  VideoPlaybackManager+Playback.swift
//  LostArchiveTV
//
//  Created by Claude on 6/26/25.
//

import Foundation
import AVFoundation
import OSLog

// MARK: - Playback Control
extension VideoPlaybackManager {
    /// Starts or resumes playback
    func play() {
        if let player = player {
            let playerPointer = String(describing: ObjectIdentifier(player))
            let itemStatus = player.currentItem?.status.rawValue ?? -1
            Logger.videoPlayback.debug("▶️ VP_MANAGER: Play requested for player \(playerPointer), item status: \(itemStatus)")
            Logger.videoPlayback.debug("Playing video")
            player.play()
            isPlaying = true
        } else {
            Logger.videoPlayback.warning("▶️ VP_MANAGER: Play requested but player is nil")
        }
    }
    
    /// Pauses playback
    func pause() {
        if let player = player {
            let playerPointer = String(describing: ObjectIdentifier(player))
            let itemStatus = player.currentItem?.status.rawValue ?? -1
            Logger.videoPlayback.debug("⏸️ VP_MANAGER: Pause requested for player \(playerPointer), item status: \(itemStatus)")
            Logger.videoPlayback.debug("Pausing video")
            player.pause()
            isPlaying = false
        } else {
            Logger.videoPlayback.warning("⏸️ VP_MANAGER: Pause requested but player is nil")
        }
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
}