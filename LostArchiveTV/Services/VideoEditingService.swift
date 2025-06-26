//
//  VideoEditingService.swift
//  LostArchiveTV
//
//  Created by Claude on 6/26/25.
//

import Foundation
import Combine
import OSLog

/// Service responsible for video editing functionality including trimming
class VideoEditingService {
    /// Publisher for video trimming events
    static var startVideoTrimmingPublisher = PassthroughSubject<Void, Never>()
    
    /// Sends a start video trimming event
    static func startVideoTrimming() async {
        Logger.videoPlayback.info("VideoEditingService: Broadcasting start video trimming event")
        await MainActor.run {
            startVideoTrimmingPublisher.send()
        }
    }
    
    /// Resets publishers for testing
    static func resetForTesting() {
        startVideoTrimmingPublisher = PassthroughSubject<Void, Never>()
    }
}