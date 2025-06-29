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

class TransitionPreloadManager: ObservableObject {
    /// Publisher for buffer status changes - publishes the combined buffer state
    static var bufferStatusPublisher = PassthroughSubject<BufferState, Never>()
    
    // Weak reference to the provider for accessing BufferingMonitors
    weak var provider: BaseVideoViewModel?
    
    // Public accessors for buffer states - query monitors directly
    var currentNextBufferState: BufferState { 
        get {
            guard let provider = provider else { return .unknown }
            return MainActor.assumeIsolated {
                provider.nextBufferingMonitor?.bufferState ?? .unknown
            }
        }
    }
    var currentPrevBufferState: BufferState { 
        get {
            guard let provider = provider else { return .unknown }
            return MainActor.assumeIsolated {
                provider.previousBufferingMonitor?.bufferState ?? .unknown
            }
        }
    }
    
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
                    Logger.caching.info("🚨 AUTO NOTIFICATION: Publishing BufferStatusChanged due to nextVideoReady change")
                    let combinedState = self.computeCombinedBufferState()
                    TransitionPreloadManager.bufferStatusPublisher.send(combinedState)
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
                    Logger.caching.info("🚨 AUTO NOTIFICATION: Publishing BufferStatusChanged due to prevVideoReady change")
                    let combinedState = self.computeCombinedBufferState()
                    TransitionPreloadManager.bufferStatusPublisher.send(combinedState)
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
    
    // MARK: - Buffer State Management
    
    /// Computes the combined buffer state by querying BufferingMonitors directly
    private func computeCombinedBufferState() -> BufferState {
        guard let provider = provider else { return .unknown }
        
        let nextState = MainActor.assumeIsolated {
            provider.nextBufferingMonitor?.bufferState ?? .unknown
        }
        let prevState = MainActor.assumeIsolated {
            provider.previousBufferingMonitor?.bufferState ?? .unknown
        }
        
        // If both are unknown, return unknown
        if nextState == .unknown && prevState == .unknown {
            return .unknown
        }
        
        // If either is unknown, use the other
        if nextState == .unknown {
            return prevState
        }
        if prevState == .unknown {
            return nextState
        }
        
        // Return the worse of the two states
        let nextIndex = BufferState.allCases.firstIndex(of: nextState) ?? 0
        let prevIndex = BufferState.allCases.firstIndex(of: prevState) ?? 0
        
        return nextIndex < prevIndex ? nextState : prevState
    }
    
    
    /// Publishes the current combined buffer state by querying monitors directly
    func publishBufferStateUpdate() {
        DispatchQueue.main.async {
            let combinedState = self.computeCombinedBufferState()
            Logger.caching.info("🚨 BUFFER STATE: Publishing combined state \(combinedState.description)")
            TransitionPreloadManager.bufferStatusPublisher.send(combinedState)
        }
    }
}