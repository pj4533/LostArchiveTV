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
        // Get the current state for logging
        let wasPlaying = isPlaying
        
        // Toggle the state
        isPlaying.toggle()
        logger.debug("trim: togglePlayback called, changing from \(wasPlaying) to \(self.isPlaying)")

        if isPlaying {
            // Verify we have a valid player - if not, attempt to recreate
            if directPlayer == nil {
                logger.error("trim: attempted to play but player is nil, attempting emergency recreation")
                
                // Reset state temporarily
                isPlaying = false
                
                // Emergency attempt to create a player directly with the simplest approach
                let fileURL = URL(fileURLWithPath: self.assetURL.path)
                
                // Check if file exists
                if !FileManager.default.fileExists(atPath: fileURL.path) {
                    logger.error("trim: emergency player creation failed - file not found")
                    return
                }
                
                // Create a very simple player
                let emergencyPlayer = AVPlayer(url: fileURL)
                emergencyPlayer.volume = 1.0
                emergencyPlayer.isMuted = false
                
                // Assign it
                self.directPlayer = emergencyPlayer
                
                if self.directPlayer == nil {
                    logger.error("trim: emergency player creation failed, giving up")
                    return
                } else {
                    logger.debug("trim: emergency player creation succeeded, continuing")
                    isPlaying = true
                    
                    // Force a play immediately to ensure it's working
                    emergencyPlayer.play()
                    
                    // Start update timer
                    startPlayheadUpdateTimer()
                    
                    // Nothing more to do - we've already started playing
                    return
                }
            }

            // CRITICAL: Configure audio session before playing
            logger.debug("trim: configuring audio session for playback")
            audioSessionManager.configureForPlayback()
            
            // Start the playhead update timer immediately
            startPlayheadUpdateTimer()
            
            // If right handle was the last one dragged, always start from the left handle
            if lastDraggedRightHandle {
                logger.debug("trim: starting from left handle (startTrimTime) after right handle drag")
                lastDraggedRightHandle = false // Reset flag once used
                seekToTime(startTrimTime)
                // Also explicitly start playback here instead of relying only on the seek completion handler
                directPlayer?.play()
                logger.debug("trim: started playback from startTrimTime: \(self.startTrimTime.seconds)s")
                return
            }
            
            // Otherwise, check if current time is within trim bounds
            if let currentPlayerTime = directPlayer?.currentTime() {
                logger.debug("trim: current player time: \(currentPlayerTime.seconds)s")
                
                if CMTimeCompare(currentPlayerTime, startTrimTime) < 0 || 
                   CMTimeCompare(currentPlayerTime, endTrimTime) > 0 {
                    // If outside trim bounds, seek to start and play from there
                    logger.debug("trim: current time outside trim bounds, seeking to startTrimTime: \(self.startTrimTime.seconds)s")
                    seekToTime(startTrimTime)
                    // Also explicitly start playback here
                    directPlayer?.play()
                    logger.debug("trim: started playback after seeking to startTrimTime")
                } else {
                    // Otherwise just play from current position
                    logger.debug("trim: playing from current position: \(currentPlayerTime.seconds)s")
                    directPlayer?.play()
                }
            } else {
                // If no current time (player might be nil), start from beginning
                logger.debug("trim: no current time available, seeking to startTrimTime: \(self.startTrimTime.seconds)s")
                seekToTime(startTrimTime)
                directPlayer?.play()
                logger.debug("trim: started playback after seeking to startTrimTime")
            }
        } else {
            // Stop the timer when paused
            logger.debug("trim: pausing playback")
            stopPlayheadUpdateTimer()
            directPlayer?.pause()
            logger.debug("trim: playback paused")
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
            guard let self = self, self.isPlaying, let player = self.directPlayer else { return }
            
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
    
    func seekToTime(_ time: CMTime, fromHandleDrag: Bool = false) {
        // Log seek operation
        logger.debug("trim: seeking to \(time.seconds) seconds, fromHandleDrag=\(fromHandleDrag)")
        
        // Update currentTime immediately so the playhead updates right away
        self.currentTime = time

        guard let player = directPlayer else {
            logger.error("trim: seekToTime failed - player is nil")
            return
        }
        
        // Make sure the time is within bounds
        let validTime = validateTimeForSeeking(time)

        // Perform the seek operation with more precise tolerances
        player.seek(to: validTime, 
                   toleranceBefore: .zero,
                   toleranceAfter: .zero) { [weak self] completed in
            guard let self = self else { 
                return 
            }
            
            if !completed {
                self.logger.error("trim: seek operation did not complete")
                return
            }
            
            self.logger.debug("trim: seek completed to \(validTime.seconds) seconds")
            
            // Update UI to reflect the actual position after seeking
            self.currentTime = player.currentTime()

            // Only restart playback if not from handle dragging and already in playing state
            if self.isPlaying && !fromHandleDrag {
                self.directPlayer?.play()
                self.logger.debug("trim: playback resumed after seek")
            }
        }
    }
    
    /// Ensures the seek time is within the valid range
    private func validateTimeForSeeking(_ time: CMTime) -> CMTime {
        // Get the asset duration for bounds checking
        let duration = assetDuration
        
        // Make sure time is not before the start of the asset
        if CMTimeCompare(time, CMTime.zero) < 0 {
            logger.debug("trim: clamping seek time to start of asset")
            return CMTime.zero
        }
        
        // Make sure time is not past the end of the asset
        if CMTimeCompare(time, duration) > 0 {
            logger.debug("trim: clamping seek time to end of asset")
            return duration
        }
        
        return time
    }
}