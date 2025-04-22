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
    }
    
    /// Process left handle drag
    func updateLeftHandleDrag(currentPosition: CGFloat, timelineWidth: CGFloat) {
        // Calculate drag distance in pixels
        let dragDelta = currentPosition - dragStartPos
        
        // Calculate time window and pixels per second
        let timeWindow = calculateVisibleTimeWindow()
        let visibleDuration = timeWindow.end - timeWindow.start
        let secondsPerPixel = visibleDuration / timelineWidth
        
        // Convert drag distance to time delta
        let timeDelta = dragDelta * secondsPerPixel
        
        // Calculate new time and apply constraints
        let newStartTime = initialHandleTime + timeDelta
        let maxStartTime = endTrimTime.seconds - minimumTrimDuration
        let clampedTime = max(0, min(newStartTime, maxStartTime))
        
        // Update start trim time
        let newTime = CMTime(seconds: clampedTime, preferredTimescale: 600)
        updateStartTrimTime(newTime)
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
    }
    
    /// Process right handle drag
    func updateRightHandleDrag(currentPosition: CGFloat, timelineWidth: CGFloat) {
        // Calculate drag distance in pixels
        let dragDelta = currentPosition - dragStartPos
        
        // Calculate time window and pixels per second
        let timeWindow = calculateVisibleTimeWindow()
        let visibleDuration = timeWindow.end - timeWindow.start
        let secondsPerPixel = visibleDuration / timelineWidth
        
        // Convert drag distance to time delta
        let timeDelta = dragDelta * secondsPerPixel
        
        // Calculate new time and apply constraints
        let newEndTime = initialHandleTime + timeDelta
        let minEndTime = startTrimTime.seconds + minimumTrimDuration
        let clampedTime = min(assetDuration.seconds, max(newEndTime, minEndTime))
        
        // Update end trim time
        let newTime = CMTime(seconds: clampedTime, preferredTimescale: 600)
        updateEndTrimTime(newTime)
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
        // Ensure start time is within valid bounds (not before 0, not after end time)
        let validStartTime = max(CMTime.zero, newStartTime)
        
        // Minimum trim duration is 1 second
        let minimumDuration = CMTime(seconds: minimumTrimDuration, preferredTimescale: 600)
        let latestPossibleStart = CMTimeSubtract(endTrimTime, minimumDuration)
        
        // Apply the valid start time
        if CMTimeCompare(validStartTime, latestPossibleStart) <= 0 {
            startTrimTime = validStartTime
            
            // Notify the owner
            onUpdateStartTime?(startTrimTime)
            
            // If current time is before new start time, seek to start time
            if CMTimeCompare(currentTime, startTrimTime) < 0 {
                onSeekToTime?(startTrimTime)
            }
        }
    }
    
    /// Update the end time of the trim window
    func updateEndTrimTime(_ newEndTime: CMTime) {
        // Ensure end time is within valid bounds (not after duration, not before start time)
        let validEndTime = min(assetDuration, newEndTime)
        
        // Minimum trim duration is 1 second
        let minimumDuration = CMTime(seconds: minimumTrimDuration, preferredTimescale: 600)
        let earliestPossibleEnd = CMTimeAdd(startTrimTime, minimumDuration)
        
        // Apply the valid end time
        if CMTimeCompare(validEndTime, earliestPossibleEnd) >= 0 {
            endTrimTime = validEndTime
            
            // Notify the owner
            onUpdateEndTime?(endTrimTime)
            
            // If current time is after new end time, seek to start time
            if CMTimeCompare(currentTime, endTrimTime) > 0 {
                onSeekToTime?(startTrimTime)
            }
        }
    }
    
    /// Update current playback time
    func updateCurrentTime(_ time: CMTime) {
        currentTime = time
    }
}