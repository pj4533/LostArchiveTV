//
//  NavigationService.swift
//  LostArchiveTV
//
//  Created by Claude on 6/26/25.
//

import Foundation
import Combine
import OSLog

/// Service responsible for navigation events and coordination
class NavigationService {
    /// Publisher for similar videos navigation events
    static var similarVideosPublisher = PassthroughSubject<SimilarVideo, Never>()
    
    /// Sends a navigation event to show similar videos
    static func showSimilarVideos(for video: SimilarVideo) async {
        Logger.navigation.info("NavigationService: Broadcasting show similar videos event for \(video.identifier)")
        await MainActor.run {
            similarVideosPublisher.send(video)
        }
    }
    
    /// Resets publishers for testing
    static func resetForTesting() {
        similarVideosPublisher = PassthroughSubject<SimilarVideo, Never>()
    }
}

// Logger extension for navigation
extension Logger {
    static let navigation = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "Navigation")
}