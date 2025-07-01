//
//  BufferingMonitor.swift
//  LostArchiveTV
//
//  Created by Claude on 2025-06-28.
//

import AVFoundation
import Combine
import Foundation
import OSLog

/// Monitors AVPlayer buffering state and calculates buffer metrics
@MainActor
final class BufferingMonitor: ObservableObject {
    // MARK: - Constants
    
    /// Target buffer duration in seconds for optimal playback
    static let targetBufferSeconds: Double = 30.0
    
    /// Minimum change in buffer seconds to update fill rate
    static let minimumBufferChangeThreshold: Double = 0.1
    
    // MARK: - Published Properties
    
    /// Buffer progress as a percentage of the target buffer (0.0 to 1.0)
    @Published internal(set) var bufferProgress: Double = 0.0
    
    /// Actual seconds buffered ahead of current playback position
    @Published internal(set) var bufferSeconds: Double = 0.0
    
    /// Current buffer state based on available buffer duration
    @Published internal(set) var bufferState: BufferState = .unknown
    
    /// Indicates if the player is actively buffering new content
    @Published internal(set) var isActivelyBuffering: Bool = false
    
    /// Indicates if playback is likely to continue without interruption
    @Published internal(set) var isPlaybackLikelyToKeepUp: Bool = false
    
    /// Rate of buffer fill/drain in seconds per second
    @Published internal(set) var bufferFillRate: Double = 0.0
    
    // MARK: - Internal Properties
    
    let logger = Logger.bufferingMonitor
    var player: AVPlayer?
    var observations: Set<AnyCancellable> = []
    
    // For tracking buffer fill rate
    var lastBufferUpdate: Date?
    var lastBufferSeconds: Double = 0.0
    
    // For stabilization of initial readings
    var isStabilized: Bool = false
    var stabilizationReadings: [Double] = []
    let stabilizationThreshold = 2 // Number of consistent readings needed
    
    // MARK: - Initialization
    
    init() {
        logger.info("📊 BufferingMonitor initialized")
    }
    
    deinit {
        // Cleanup will be handled by the caller
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring the given AVPlayer
    /// - Parameter player: The AVPlayer to monitor
    func startMonitoring(_ player: AVPlayer) {
        logger.info("🚀 startMonitoring called with player: \(String(describing: Unmanaged.passUnretained(player).toOpaque()))")
        
        cleanup()
        self.player = player
        
        logger.info("📊 Starting buffer monitoring for player")
        Logger.preloading.info("🔌 BUFFER MONITOR: Started monitoring player \(String(describing: Unmanaged.passUnretained(player).toOpaque()))")
        
        // Reset stabilization state
        isStabilized = false
        stabilizationReadings.removeAll()
        logger.debug("🔄 Reset stabilization state - isStabilized: false, readings cleared")
        
        setupObservations()
        
        // Log initial player state
        if let currentItem = player.currentItem {
            logger.debug("📱 Initial player state - currentItem: \(currentItem), status: \(currentItem.status.rawValue)")
            logger.debug("📊 Initial buffer state - loadedTimeRanges: \(currentItem.loadedTimeRanges.count) ranges")
        } else {
            logger.warning("⚠️ No current item in player when starting monitoring")
        }
        
        // Perform initial buffer check immediately
        logger.debug("🔍 Performing initial buffer check")
        updateBufferMetrics()
        
        // Schedule additional stabilization checks
        Task {
            logger.debug("⏰ Starting stabilization check sequence")
            
            // Wait a moment for player to settle
            try? await Task.sleep(for: .milliseconds(100))
            logger.debug("⏰ First stabilization check (100ms)")
            updateBufferMetrics()
            
            // Another check after a short delay
            try? await Task.sleep(for: .milliseconds(200))
            logger.debug("⏰ Second stabilization check (300ms total)")
            updateBufferMetrics()
        }
    }
    
    /// Stop monitoring and clean up resources
    func stopMonitoring() {
        logger.info("🛑 stopMonitoring called")
        let playerAddress = player.map { String(describing: Unmanaged.passUnretained($0).toOpaque()) } ?? "nil"
        logger.info("📊 Stopping buffer monitoring for player: \(playerAddress)")
        cleanup()
    }
}