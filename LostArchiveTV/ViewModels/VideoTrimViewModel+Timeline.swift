//
//  VideoTrimViewModel+Timeline.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import Foundation
import AVFoundation
import OSLog

// MARK: - Timeline Functions
extension VideoTrimViewModel {
    /// Return the fixed visible time window for timeline display
    func calculateVisibleTimeWindow() -> (start: Double, end: Double) {
        return timelineManager.calculateVisibleTimeWindow()
    }
    
    /// Convert a time value to a position in the timeline (in pixels)
    func timeToPosition(timeInSeconds: Double, timelineWidth: CGFloat) -> CGFloat {
        return timelineManager.timeToPosition(timeInSeconds: timeInSeconds, timelineWidth: timelineWidth)
    }
    
    /// Convert a position in the timeline to time value
    func positionToTime(position: CGFloat, timelineWidth: CGFloat) -> Double {
        return timelineManager.positionToTime(position: position, timelineWidth: timelineWidth)
    }
}