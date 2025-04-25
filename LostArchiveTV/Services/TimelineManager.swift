//
//  TimelineManager.swift
//  LostArchiveTV
//
//  Created by Claude on 4/25/25.
//

import Foundation
import AVFoundation
import OSLog

class TimelineManager {
    // Trim bounds
    private(set) var startTrimTime: CMTime
    private(set) var endTrimTime: CMTime
    private(set) var currentTime: CMTime
    private(set) var assetDuration: CMTime
    
    // Dragging state
    private(set) var isDraggingLeftHandle = false
    private(set) var isDraggingRightHandle = false
    
    // Fixed visible window (calculated once at initialization)
    private let initialVisibleWindow: (start: Double, end: Double)
    
    // Minimum distance between handles in seconds
    private let minimumTrimDuration: Double = 1.0
    
    // Callbacks for updating the view model
    var onUpdateStartTime: ((CMTime) -> Void)?
    var onUpdateEndTime: ((CMTime) -> Void)?
    var onSeekToTime: ((CMTime) -> Void)?
    
    init(startTrimTime: CMTime, endTrimTime: CMTime, currentTime: CMTime, assetDuration: CMTime) {
        self.startTrimTime = startTrimTime
        self.endTrimTime = endTrimTime
        self.currentTime = currentTime
        self.assetDuration = assetDuration
        
        // Calculate the initial visible window once during initialization
        let selectionDuration = endTrimTime.seconds - startTrimTime.seconds
        let paddingAmount = selectionDuration * 0.2
        let visibleStart = max(0, startTrimTime.seconds - paddingAmount)
        let visibleEnd = min(assetDuration.seconds, endTrimTime.seconds + paddingAmount)
        self.initialVisibleWindow = (visibleStart, visibleEnd)
    }
    
    // Update current time without affecting trim bounds
    func updateCurrentTime(_ time: CMTime) {
        self.currentTime = time
    }
    
    // Return the fixed visible time window for timeline display
    func calculateVisibleTimeWindow() -> (start: Double, end: Double) {
        // Always return the same fixed window that was calculated during initialization
        return initialVisibleWindow
    }
    
    // Convert a time value to a position in the timeline
    func timeToPosition(timeInSeconds: Double, timelineWidth: CGFloat) -> CGFloat {
        // Get the current visible window
        let visibleWindow = calculateVisibleTimeWindow()
        let visibleStart = visibleWindow.start
        let visibleEnd = visibleWindow.end
        let visibleDuration = visibleEnd - visibleStart
        
        // Protect against division by zero
        guard visibleDuration > 0 else { return 0 }
        
        // Calculate normalized position (0 to 1) within visible window
        let normalizedPosition = (timeInSeconds - visibleStart) / visibleDuration
        
        // Clamp to valid range
        let clampedPosition = max(0, min(1, normalizedPosition))
        
        // Convert to UI position
        return CGFloat(clampedPosition) * timelineWidth
    }
    
    // Convert a position in the timeline to a time value
    func positionToTime(position: CGFloat, timelineWidth: CGFloat) -> Double {
        // Get the current visible window
        let visibleWindow = calculateVisibleTimeWindow()
        let visibleStart = visibleWindow.start
        let visibleEnd = visibleWindow.end
        let visibleDuration = visibleEnd - visibleStart
        
        // Protect against division by zero
        guard timelineWidth > 0 else { return visibleStart }
        
        // Calculate normalized position (0 to 1)
        let normalizedPosition = Double(position) / Double(timelineWidth)
        
        // Clamp to valid range
        let clampedPosition = max(0, min(1, normalizedPosition))
        
        // Convert to time value
        return visibleStart + (clampedPosition * visibleDuration)
    }
    
    // MARK: - Left Handle Dragging
    
    func startLeftHandleDrag(position: CGFloat) {
        isDraggingLeftHandle = true
    }
    
    func updateLeftHandleDrag(currentPosition: CGFloat, timelineWidth: CGFloat) {
        guard isDraggingLeftHandle else { return }
        
        // Convert position to time
        let newStartTimeSeconds = positionToTime(position: currentPosition, timelineWidth: timelineWidth)
        
        // Constrain within valid range (0 to endTrimTime - minimumTrimDuration)
        let maxStartTime = endTrimTime.seconds - minimumTrimDuration
        let constrainedStartTime = max(0, min(newStartTimeSeconds, maxStartTime))
        
        // Create CMTime from constrained seconds
        let newStartTime = CMTime(seconds: constrainedStartTime, preferredTimescale: 600)
        
        // Update start trim time
        startTrimTime = newStartTime
        
        // Notify view model
        onUpdateStartTime?(newStartTime)
        
        // Also update current time to match the handle
        onSeekToTime?(newStartTime)
    }
    
    func endLeftHandleDrag() {
        // Stop dragging state
        isDraggingLeftHandle = false
    }
    
    // MARK: - Right Handle Dragging
    
    func startRightHandleDrag(position: CGFloat) {
        isDraggingRightHandle = true
    }
    
    func updateRightHandleDrag(currentPosition: CGFloat, timelineWidth: CGFloat) {
        guard isDraggingRightHandle else { return }
        
        // Convert position to time
        let newEndTimeSeconds = positionToTime(position: currentPosition, timelineWidth: timelineWidth)
        
        // Constrain within valid range (startTrimTime + minimumTrimDuration to assetDuration)
        let minEndTime = startTrimTime.seconds + minimumTrimDuration
        let constrainedEndTime = min(assetDuration.seconds, max(newEndTimeSeconds, minEndTime))
        
        // Create CMTime from constrained seconds
        let newEndTime = CMTime(seconds: constrainedEndTime, preferredTimescale: 600)
        
        // Update end trim time
        endTrimTime = newEndTime
        
        // Notify view model
        onUpdateEndTime?(newEndTime)
        
        // Also update current time to match the handle
        onSeekToTime?(newEndTime)
    }
    
    func endRightHandleDrag() {
        // Stop dragging state
        isDraggingRightHandle = false
    }
    
    // MARK: - Timeline Scrubbing
    
    func scrubTimeline(position: CGFloat, timelineWidth: CGFloat) {
        // Convert position to time
        let timeSeconds = positionToTime(position: position, timelineWidth: timelineWidth)
        
        // Constrain to trim bounds
        let constrainedTime = max(startTrimTime.seconds, min(endTrimTime.seconds, timeSeconds))
        
        // Create CMTime from constrained seconds
        let newTime = CMTime(seconds: constrainedTime, preferredTimescale: 600)
        
        // Update current time
        currentTime = newTime
        
        // Notify view model for seeking
        onSeekToTime?(newTime)
    }
}