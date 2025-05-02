//
//  TimelineManagerTests.swift
//  LostArchiveTVTests
//
//  Created by Claude on 5/2/25.
//

import Testing
import AVFoundation
@testable import LATV

struct TimelineManagerTests {
    
    func createTimelineManager() -> TimelineManager {
        // Create a TimelineManager with a 60-second asset
        // Initial trim range: 10-50 seconds, current position at 15 seconds
        let assetDuration = CMTime(seconds: 60, preferredTimescale: 600)
        let startTrim = CMTime(seconds: 10, preferredTimescale: 600)
        let endTrim = CMTime(seconds: 50, preferredTimescale: 600)
        let currentTime = CMTime(seconds: 15, preferredTimescale: 600)
        
        return TimelineManager(
            startTrimTime: startTrim,
            endTrimTime: endTrim,
            currentTime: currentTime,
            assetDuration: assetDuration
        )
    }
    
    @Test
    func initialization_setsCorrectInitialValues() {
        // Arrange
        let assetDuration = CMTime(seconds: 60, preferredTimescale: 600)
        let startTrim = CMTime(seconds: 10, preferredTimescale: 600)
        let endTrim = CMTime(seconds: 50, preferredTimescale: 600)
        let currentTime = CMTime(seconds: 15, preferredTimescale: 600)
        
        // Act
        let manager = TimelineManager(
            startTrimTime: startTrim,
            endTrimTime: endTrim,
            currentTime: currentTime,
            assetDuration: assetDuration
        )
        
        // Assert
        #expect(manager.startTrimTime.seconds == 10)
        #expect(manager.endTrimTime.seconds == 50)
        #expect(manager.currentTime.seconds == 15)
        #expect(manager.assetDuration.seconds == 60)
        #expect(!manager.isDraggingLeftHandle)
        #expect(!manager.isDraggingRightHandle)
    }
    
    @Test
    func updateCurrentTime_updatesValue() {
        // Arrange
        let manager = createTimelineManager()
        let newTime = CMTime(seconds: 25, preferredTimescale: 600)
        
        // Act
        manager.updateCurrentTime(newTime)
        
        // Assert
        #expect(manager.currentTime.seconds == 25)
    }
    
    @Test
    func calculateVisibleTimeWindow_returnsFixedPaddedWindow() {
        // Arrange
        let manager = createTimelineManager()
        
        // Act
        let window = manager.calculateVisibleTimeWindow()
        
        // Assert
        // Expected: 10-50 seconds with 20% padding
        // Selection duration = 40 seconds, padding = 8 seconds
        // Visible window should be 2-58 seconds
        #expect(window.start >= 1.9 && window.start <= 2.1)
        #expect(window.end >= 57.9 && window.end <= 58.1)
    }
    
    @Test
    func timeToPosition_convertsTimeToPosition() {
        // Arrange
        let manager = createTimelineManager()
        let timelineWidth: CGFloat = 1000
        
        // Act
        // Test times at different parts of the timeline
        let startPos = manager.timeToPosition(timeInSeconds: 2.0, timelineWidth: timelineWidth)
        let middlePos = manager.timeToPosition(timeInSeconds: 30.0, timelineWidth: timelineWidth)
        let endPos = manager.timeToPosition(timeInSeconds: 58.0, timelineWidth: timelineWidth)
        
        // Assert
        // Based on visible window of 2-58 seconds (56-second duration)
        #expect(startPos >= -0.1 && startPos <= 0.1) // Start of visible window
        #expect(middlePos >= 490 && middlePos <= 510) // Middle
        #expect(endPos >= 999 && endPos <= 1001) // End of visible window
    }
    
    @Test
    func positionToTime_convertsPositionToTime() {
        // Arrange
        let manager = createTimelineManager()
        let timelineWidth: CGFloat = 1000
        
        // Act
        // Test positions at different parts of the timeline
        let startTime = manager.positionToTime(position: 0, timelineWidth: timelineWidth)
        let middleTime = manager.positionToTime(position: 500, timelineWidth: timelineWidth)
        let endTime = manager.positionToTime(position: 1000, timelineWidth: timelineWidth)
        
        // Assert
        // Based on visible window of 2-58 seconds (56-second duration)
        #expect(startTime >= 1.9 && startTime <= 2.1) // Start of visible window
        #expect(middleTime >= 29.9 && middleTime <= 30.1) // Middle
        #expect(endTime >= 57.9 && endTime <= 58.1) // End of visible window
    }
    
    @Test
    func leftHandleDragging_respectsMinimumTrimDuration() {
        // Arrange
        let manager = createTimelineManager()
        let timelineWidth: CGFloat = 1000
        var capturedStartTime: CMTime?
        
        manager.onUpdateStartTime = { time in
            capturedStartTime = time
        }
        
        // Act
        // Start dragging
        manager.startLeftHandleDrag(position: 0)
        
        // Try to drag right handle to a position too close to end trim
        // Current end time is at 50 seconds
        // With minimum duration of a second, the furthest allowed left handle position
        // would be at 49 seconds, which is near the end of the timeline
        let farRightPosition = manager.timeToPosition(timeInSeconds: 51, timelineWidth: timelineWidth)
        manager.updateLeftHandleDrag(currentPosition: farRightPosition, timelineWidth: timelineWidth)
        
        // Assert
        #expect(manager.isDraggingLeftHandle)
        #expect(capturedStartTime != nil)
        
        // Should be clamped to 49 seconds (endTrimTime - minimumTrimDuration)
        #expect(capturedStartTime != nil)
        #expect(capturedStartTime!.seconds >= 48.9 && capturedStartTime!.seconds <= 49.1)
        #expect(manager.startTrimTime.seconds >= 48.9 && manager.startTrimTime.seconds <= 49.1)
        
        // End dragging
        manager.endLeftHandleDrag()
        #expect(!manager.isDraggingLeftHandle)
    }
    
    @Test
    func rightHandleDragging_respectsMinimumTrimDuration() {
        // Arrange
        let manager = createTimelineManager()
        let timelineWidth: CGFloat = 1000
        var capturedEndTime: CMTime?
        
        manager.onUpdateEndTime = { time in
            capturedEndTime = time
        }
        
        // Act
        // Start dragging
        manager.startRightHandleDrag(position: 0)
        
        // Try to drag right handle to a position too close to start trim
        // Current start time is at 10 seconds
        // With minimum duration of a second, the closest allowed right handle position
        // would be at 11 seconds, which is near the start of the visible area
        let farLeftPosition = manager.timeToPosition(timeInSeconds: 9, timelineWidth: timelineWidth)
        manager.updateRightHandleDrag(currentPosition: farLeftPosition, timelineWidth: timelineWidth)
        
        // Assert
        #expect(manager.isDraggingRightHandle)
        #expect(capturedEndTime != nil)
        
        // Should be clamped to 11 seconds (startTrimTime + minimumTrimDuration)
        #expect(capturedEndTime != nil)
        #expect(capturedEndTime!.seconds >= 10.9 && capturedEndTime!.seconds <= 11.1)
        #expect(manager.endTrimTime.seconds >= 10.9 && manager.endTrimTime.seconds <= 11.1)
        
        // End dragging
        manager.endRightHandleDrag()
        #expect(!manager.isDraggingRightHandle)
    }
    
    @Test
    func scrubTimeline_constrainsPositionWithinTrimBounds() {
        // Arrange
        let manager = createTimelineManager()
        let timelineWidth: CGFloat = 1000
        var capturedSeekTime: CMTime?
        
        manager.onSeekToTime = { time in
            capturedSeekTime = time
        }
        
        // Act - try to scrub before start trim bound
        let beforeStartPosition = manager.timeToPosition(timeInSeconds: 5, timelineWidth: timelineWidth)
        manager.scrubTimeline(position: beforeStartPosition, timelineWidth: timelineWidth)
        
        // Assert
        #expect(capturedSeekTime != nil)
        #expect(capturedSeekTime != nil)
        #expect(capturedSeekTime!.seconds >= 9.9 && capturedSeekTime!.seconds <= 10.1) // Clamped to start trim
        
        // Reset
        capturedSeekTime = nil
        
        // Act - try to scrub after end trim bound
        let afterEndPosition = manager.timeToPosition(timeInSeconds: 55, timelineWidth: timelineWidth)
        manager.scrubTimeline(position: afterEndPosition, timelineWidth: timelineWidth)
        
        // Assert
        #expect(capturedSeekTime != nil)
        #expect(capturedSeekTime != nil)
        #expect(capturedSeekTime!.seconds >= 49.9 && capturedSeekTime!.seconds <= 50.1) // Clamped to end trim
        
        // Reset
        capturedSeekTime = nil
        
        // Act - scrub within trim bounds
        let validPosition = manager.timeToPosition(timeInSeconds: 30, timelineWidth: timelineWidth)
        manager.scrubTimeline(position: validPosition, timelineWidth: timelineWidth)
        
        // Assert
        #expect(capturedSeekTime != nil)
        #expect(capturedSeekTime != nil)
        #expect(capturedSeekTime!.seconds >= 29.9 && capturedSeekTime!.seconds <= 30.1) // Valid position
    }
}