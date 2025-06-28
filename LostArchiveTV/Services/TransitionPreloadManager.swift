//
//  TransitionPreloadManager.swift
//  LostArchiveTV
//
//  Created by Claude on 4/25/25.
//

import SwiftUI
import AVKit
import OSLog
import Foundation
import Combine

@MainActor
class TransitionPreloadManager: ObservableObject {
    /// Publisher for cache status changes
    static var cacheStatusPublisher = PassthroughSubject<Void, Never>()
    // Next (down) video properties
    @Published var nextVideoReady = false {
        didSet {
            // Log when the next video ready state changes
            if oldValue != self.nextVideoReady {
                Logger.caching.info("🚦 TRANSITION STATUS: Next video ready changed to \(self.nextVideoReady ? "true" : "false") on manager \(String(describing: ObjectIdentifier(self)))")

                // Debug - log the stack trace to see where this is being set
                let symbols = Thread.callStackSymbols.prefix(5).joined(separator: "\n")
                Logger.caching.info("🔍 CALL STACK: next state changed from \(oldValue) to \(self.nextVideoReady):\n\(symbols)")

                // Always post notification when nextVideoReady changes to ensure UI updates
                // This helps prevent mismatch between UI and actual swipe availability
                DispatchQueue.main.async {
                    Logger.caching.info("🚨 AUTO NOTIFICATION: Publishing CacheStatusChanged due to nextVideoReady change")
                    TransitionPreloadManager.cacheStatusPublisher.send()
                }
            }
        }
    }
    @Published var nextPlayer: AVPlayer?
    @Published var nextTitle: String = ""
    @Published var nextCollection: String = ""
    @Published var nextDescription: String = ""
    @Published var nextIdentifier: String = ""
    @Published var nextFilename: String = ""
    @Published var nextTotalFiles: Int = 0

    // Previous (up) video properties
    @Published var prevVideoReady = false {
        didSet {
            // Log when the previous video ready state changes
            if oldValue != self.prevVideoReady {
                Logger.caching.info("🚦 TRANSITION STATUS: Previous video ready changed to \(self.prevVideoReady ? "true" : "false") on manager \(String(describing: ObjectIdentifier(self)))")

                // Always post notification when prevVideoReady changes to ensure UI updates
                // This helps prevent mismatch between UI and actual swipe availability
                DispatchQueue.main.async {
                    Logger.caching.info("🚨 AUTO NOTIFICATION: Publishing CacheStatusChanged due to prevVideoReady change")
                    TransitionPreloadManager.cacheStatusPublisher.send()
                }
            }
        }
    }
    @Published var prevPlayer: AVPlayer?
    @Published var prevTitle: String = ""
    @Published var prevCollection: String = ""
    @Published var prevDescription: String = ""
    @Published var prevIdentifier: String = ""
    @Published var prevFilename: String = ""
    @Published var prevTotalFiles: Int = 0
}