//
//  VideoTrimViewModel+HandleDragging.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import Foundation
import AVFoundation
import OSLog

// MARK: - Handle Dragging
extension VideoTrimViewModel {
    func startLeftHandleDrag(position: CGFloat) {
        // Pause playback if currently playing
        if isPlaying {
            playbackManager.player?.pause()
            isPlaying = false
        }
        
        // Show play button when interacting with handles
        shouldShowPlayButton = true
        
        timelineManager.startLeftHandleDrag(position: position)
        isDraggingLeftHandle = timelineManager.isDraggingLeftHandle
    }
    
    func updateLeftHandleDrag(currentPosition: CGFloat, timelineWidth: CGFloat) {
        timelineManager.updateLeftHandleDrag(currentPosition: currentPosition, timelineWidth: timelineWidth)
        // Update current time to follow the handle position
        self.currentTime = self.startTrimTime
        // Explicitly seek to start trim time so the video frame shows the handle position
        if let player = playbackManager.player {
            player.seek(to: self.startTrimTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    func endLeftHandleDrag() {
        timelineManager.endLeftHandleDrag()
        isDraggingLeftHandle = timelineManager.isDraggingLeftHandle
        lastDraggedRightHandle = false
    }

    func startRightHandleDrag(position: CGFloat) {
        // Pause playback if currently playing
        if isPlaying {
            playbackManager.player?.pause()
            isPlaying = false
        }

        // Show play button when interacting with handles
        shouldShowPlayButton = true

        timelineManager.startRightHandleDrag(position: position)
        isDraggingRightHandle = timelineManager.isDraggingRightHandle
    }

    func updateRightHandleDrag(currentPosition: CGFloat, timelineWidth: CGFloat) {
        timelineManager.updateRightHandleDrag(currentPosition: currentPosition, timelineWidth: timelineWidth)
        // Update current time to follow the handle position
        self.currentTime = self.endTrimTime
        // Explicitly seek to end trim time so the video frame shows the handle position
        if let player = playbackManager.player {
            player.seek(to: self.endTrimTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }
    
    func endRightHandleDrag() {
        timelineManager.endRightHandleDrag()
        isDraggingRightHandle = timelineManager.isDraggingRightHandle
        lastDraggedRightHandle = true
    }
    
    func scrubTimeline(position: CGFloat, timelineWidth: CGFloat) {
        // Pause playback if currently playing
        if isPlaying {
            playbackManager.player?.pause()
            isPlaying = false
        }
        
        // Show play button when interacting with timeline
        shouldShowPlayButton = true
        
        // Get the time for this position
        let newTimeSeconds = timelineManager.positionToTime(position: position, timelineWidth: timelineWidth)
        
        // Constrain to trim bounds
        let constrainedTime = max(startTrimTime.seconds, min(endTrimTime.seconds, newTimeSeconds))
        
        // Create CMTime
        let newTime = CMTime(seconds: constrainedTime, preferredTimescale: 600)
        
        // Update our current time directly
        self.currentTime = newTime
        
        // Send to timeline manager
        timelineManager.scrubTimeline(position: position, timelineWidth: timelineWidth)
        
        // When user manually scrubs timeline, reset the handle drag tracking
        lastDraggedRightHandle = false
    }
}