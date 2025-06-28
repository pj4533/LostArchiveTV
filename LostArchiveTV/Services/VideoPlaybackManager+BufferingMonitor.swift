//
//  VideoPlaybackManager+BufferingMonitor.swift
//  LostArchiveTV
//
//  Created by Claude on 2025-06-28.
//

import Foundation
import AVFoundation
import OSLog

// MARK: - BufferingMonitor Integration
extension VideoPlaybackManager {
    
    /// Connects a BufferingMonitor to observe the current player
    /// - Parameter monitor: The BufferingMonitor to connect
    func connectBufferingMonitor(_ monitor: BufferingMonitor?) {
        guard let monitor = monitor else {
            Logger.videoPlayback.debug("🔍 VP_MANAGER: No monitor provided to connect")
            return
        }
        
        guard let player = self.player else {
            Logger.videoPlayback.warning("⚠️ VP_MANAGER: Cannot connect monitor - no player available")
            Task { @MainActor in
                monitor.stopMonitoring()
            }
            return
        }
        
        Logger.videoPlayback.info("🔍 VP_MANAGER: Connecting BufferingMonitor to player")
        Task { @MainActor in
            monitor.startMonitoring(player)
        }
    }
    
    /// Disconnects a BufferingMonitor from observing the player
    /// - Parameter monitor: The BufferingMonitor to disconnect
    func disconnectBufferingMonitor(_ monitor: BufferingMonitor?) {
        guard let monitor = monitor else { return }
        
        Logger.videoPlayback.info("🔍 VP_MANAGER: Disconnecting BufferingMonitor from player")
        Task { @MainActor in
            monitor.stopMonitoring()
        }
    }
}