import Foundation
import SwiftUI
import AVFoundation

/// Manages timeline calculations and handle dragging for video trimming
class TimelineManager {
    // Timeline view configuration
    private let minimumTrimDuration: Double
    private var initialHandleTime: Double = 0  // For tracking drag start
    private var dragStartPos: CGFloat = 0      // Starting position of drag
    
    // Fixed timeline window (calculated once at init)
    private var timelineWindowStart: Double = 0
    private var timelineWindowEnd: Double = 0
    private let paddingSeconds: Double
    
    // Handle dragging state 
    private(set) var isDraggingLeftHandle = false
    private(set) var isDraggingRightHandle = false
    
    // Current trim points
    var startTrimTime: CMTime
    var endTrimTime: CMTime
    var currentTime: CMTime
    
    // Asset properties
    let assetDuration: CMTime
    
    // Functions to update trim points
    var onUpdateStartTime: ((CMTime) -> Void)?
    var onUpdateEndTime: ((CMTime) -> Void)?
    var onSeekToTime: ((CMTime) -> Void)?
    
    init(
        startTrimTime: CMTime,
        endTrimTime: CMTime,
        currentTime: CMTime,
        assetDuration: CMTime,
        minimumTrimDuration: Double = 1.0,
        paddingSeconds: Double = 15.0
    ) {
        self.startTrimTime = startTrimTime
        self.endTrimTime = endTrimTime
        self.currentTime = currentTime
        self.assetDuration = assetDuration
        self.minimumTrimDuration = minimumTrimDuration
        self.paddingSeconds = paddingSeconds
        
        // Calculate fixed timeline window with padding
        let startTimeSeconds = startTrimTime.seconds
        let endTimeSeconds = endTrimTime.seconds
        let totalDuration = assetDuration.seconds
        
        self.timelineWindowStart = max(0, startTimeSeconds - paddingSeconds)
        self.timelineWindowEnd = min(totalDuration, endTimeSeconds + paddingSeconds)
    }
    
    /// Return the fixed visible time window for timeline display (calculated once at init)
    func calculateVisibleTimeWindow() -> (start: Double, end: Double) {
        return (timelineWindowStart, timelineWindowEnd)
    }
    
    /// Convert a time value to a position in the timeline (in pixels)
    func timeToPosition(timeInSeconds: Double, timelineWidth: CGFloat) -> CGFloat {
        let timeWindow = calculateVisibleTimeWindow()
        let visibleDuration = timeWindow.end - timeWindow.start
        let pixelsPerSecond = timelineWidth / visibleDuration
        
        return (timeInSeconds - timeWindow.start) * pixelsPerSecond
    }
    
    /// Convert a position in the timeline to time value
    func positionToTime(position: CGFloat, timelineWidth: CGFloat) -> Double {
        let timeWindow = calculateVisibleTimeWindow()
        let visibleDuration = timeWindow.end - timeWindow.start
        let secondsPerPixel = visibleDuration / timelineWidth
        
        let timeInSeconds = timeWindow.start + (position * secondsPerPixel)
        return max(0, min(timeInSeconds, assetDuration.seconds))
    }
    
    /// Start dragging the left (start) handle
    func startLeftHandleDrag(position: CGFloat) {
        isDraggingLeftHandle = true
        dragStartPos = position
        initialHandleTime = startTrimTime.seconds
        
        // Immediately seek to the start trim time to show the frame at the handle
        onSeekToTime?(startTrimTime)
    }
    
    /// Process left handle drag
    func updateLeftHandleDrag(currentPosition: CGFloat, timelineWidth: CGFloat) {
        // Calculate the time at this position directly
        let timeInSeconds = positionToTime(position: currentPosition, timelineWidth: timelineWidth)
        
        // Apply constraints to ensure it's valid
        let maxStartTime = endTrimTime.seconds - minimumTrimDuration
        let clampedTime = max(0, min(timeInSeconds, maxStartTime))
        
        // Create time object
        let newTime = CMTime(seconds: clampedTime, preferredTimescale: 600)
        
        // Set start trim time
        startTrimTime = newTime
        
        // Update the caller
        onUpdateStartTime?(newTime)
        
        // Set the playhead to this position
        onSeekToTime?(newTime)
    }
    
    /// End left handle drag
    func endLeftHandleDrag() {
        isDraggingLeftHandle = false
    }
    
    /// Start dragging the right (end) handle
    func startRightHandleDrag(position: CGFloat) {
        isDraggingRightHandle = true
        dragStartPos = position
        initialHandleTime = endTrimTime.seconds
        
        // Immediately seek to the end trim time to show the frame at the handle
        onSeekToTime?(endTrimTime)
    }
    
    /// Process right handle drag
    func updateRightHandleDrag(currentPosition: CGFloat, timelineWidth: CGFloat) {
        // Calculate the time at this position directly
        let timeInSeconds = positionToTime(position: currentPosition, timelineWidth: timelineWidth)
        
        // Apply constraints to ensure it's valid
        let minEndTime = startTrimTime.seconds + minimumTrimDuration
        let clampedTime = min(assetDuration.seconds, max(timeInSeconds, minEndTime))
        
        // Create time object
        let newTime = CMTime(seconds: clampedTime, preferredTimescale: 600)
        
        // Set end trim time
        endTrimTime = newTime
        
        // Update the caller
        onUpdateEndTime?(newTime)
        
        // Set the playhead to this position
        onSeekToTime?(newTime)
    }
    
    /// End right handle drag
    func endRightHandleDrag() {
        isDraggingRightHandle = false
    }
    
    /// Handle timeline scrubbing
    func scrubTimeline(position: CGFloat, timelineWidth: CGFloat) {
        let timeInSeconds = positionToTime(position: position, timelineWidth: timelineWidth)
        let newTime = CMTime(seconds: timeInSeconds, preferredTimescale: 600)
        onSeekToTime?(newTime)
    }
    
    /// Update the start time of the trim window
    func updateStartTrimTime(_ newStartTime: CMTime) {
        // This is now just a passthrough method since we've moved the logic to updateLeftHandleDrag
        // We keep it for compatibility with code that still calls this directly
        
        // Notify the owner about the change
        onUpdateStartTime?(newStartTime)
    }
    
    /// Update the end time of the trim window
    func updateEndTrimTime(_ newEndTime: CMTime) {
        // This is now just a passthrough method since we've moved the logic to updateRightHandleDrag
        // We keep it for compatibility with code that still calls this directly
        
        // Notify the owner about the change
        onUpdateEndTime?(newEndTime)
    }
    
    /// Update current playback time
    func updateCurrentTime(_ time: CMTime) {
        currentTime = time
    }
}