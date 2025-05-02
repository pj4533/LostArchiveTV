//
//  VideoTrimViewModel+PlaybackControl.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import Foundation
import AVKit
import AVFoundation
import OSLog

// MARK: - Playback Control
extension VideoTrimViewModel {
    
    func togglePlayback() {
        isPlaying.toggle()
        
        if isPlaying {
            // Start the playhead update timer when playing
            startPlayheadUpdateTimer()
            
            // If right handle was the last one dragged, always start from the left handle
            if lastDraggedRightHandle {
                lastDraggedRightHandle = false // Reset flag once used
                seekToTime(startTrimTime)
                // Also explicitly start playback here instead of relying only on the seek completion handler
                playerManager.play()
                return
            }
            
            // Otherwise, check if current time is within trim bounds
            let currentPlayerTime = player.currentTime()
            
            if CMTimeCompare(currentPlayerTime, startTrimTime) < 0 || 
               CMTimeCompare(currentPlayerTime, endTrimTime) > 0 {
                // If outside trim bounds, seek to start and play from there
                seekToTime(startTrimTime)
                // Also explicitly start playback here
                playerManager.play()
            } else {
                // Otherwise just play from current position
                playerManager.play()
            }
        } else {
            // Stop the timer when paused
            stopPlayheadUpdateTimer()
            playerManager.pause()
        }
        
        // Show the play button again when interacting with the timeline, dragging handles, or tapping the video
        // This is handled in the UI layer by setting shouldShowPlayButton = false when button is tapped
    }
    
    // Use a simple timer to update the playhead position during playback
    func startPlayheadUpdateTimer() {
        // Stop any existing timer first
        stopPlayheadUpdateTimer()
        
        // Create a timer that fires 10 times per second
        playheadUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, self.isPlaying, let player = self.playerManager.player else { return }
            
            // Update our currentTime property with the player's current time
            let time = player.currentTime()
            self.currentTime = time
            
            // Check if we've reached the end of the trim range
            if CMTimeCompare(time, self.endTrimTime) >= 0 {
                self.logger.debug("Reached end of trim section, looping back")
                self.seekToTime(self.startTrimTime)
            }
        }
    }
    
    func stopPlayheadUpdateTimer() {
        playheadUpdateTimer?.invalidate()
        playheadUpdateTimer = nil
    }
    
    func seekToTime(_ time: CMTime) {
        // Update currentTime immediately so the playhead updates right away
        self.currentTime = time
        
        // Seek with completion handler to ensure operation finishes
        playerManager.seek(to: time) { [weak self] completed in
            guard let self = self, completed else { return }
            
            // If player is already in playing state, ensure it's actually playing
            if self.isPlaying {
                self.playerManager.play()
            }
        }
    }
}