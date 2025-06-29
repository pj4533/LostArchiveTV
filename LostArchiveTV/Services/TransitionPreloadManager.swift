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
    
    // Buffer state tracking (kept for backward compatibility but will query monitors)
    private var nextBufferState: BufferState = .unknown
    private var prevBufferState: BufferState = .unknown
    
    // Public accessors for buffer states
    var currentNextBufferState: BufferState { nextBufferState }
    var currentPrevBufferState: BufferState { prevBufferState }
    
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
    
    /// Computes the combined buffer state based on next and previous buffer states
    private func computeCombinedBufferState() -> BufferState {
        
        // If both are unknown, return unknown
        if nextBufferState == .unknown && prevBufferState == .unknown {
            return .unknown
        }
        
        // If either is unknown, use the other
        if nextBufferState == .unknown {
            return prevBufferState
        }
        if prevBufferState == .unknown {
            return nextBufferState
        }
        
        // Return the worse of the two states
        let nextIndex = BufferState.allCases.firstIndex(of: nextBufferState) ?? 0
        let prevIndex = BufferState.allCases.firstIndex(of: prevBufferState) ?? 0
        
        return nextIndex < prevIndex ? nextBufferState : prevBufferState
    }
    
    /// Updates the buffer state for next video and publishes if changed
    func updateNextBufferState(_ state: BufferState) {
        guard nextBufferState != state else { return }
        
        Logger.preloading.info("📈 TRANSITION MGR: Updating nextBufferState from \(self.nextBufferState.rawValue) to \(state.rawValue)")
        nextBufferState = state
        let combinedState = computeCombinedBufferState()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            Logger.caching.info("🚨 BUFFER STATE: Publishing combined state \(combinedState.description) (next: \(state.description))")
            Logger.preloading.info("📢 TRANSITION MGR: Published buffer state - Combined: \(combinedState.rawValue), Next: \(state.rawValue), Prev: \(self.prevBufferState.rawValue)")
            TransitionPreloadManager.bufferStatusPublisher.send(combinedState)
        }
    }
    
    /// Updates the buffer state for previous video and publishes if changed
    func updatePrevBufferState(_ state: BufferState) {
        guard prevBufferState != state else { return }
        
        prevBufferState = state
        let combinedState = computeCombinedBufferState()
        
        DispatchQueue.main.async {
            Logger.caching.info("🚨 BUFFER STATE: Publishing combined state \(combinedState.description) (prev: \(state.description))")
            TransitionPreloadManager.bufferStatusPublisher.send(combinedState)
        }
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