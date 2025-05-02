import Foundation
import AVFoundation
import SwiftUI
import OSLog
import Photos

@MainActor
class VideoTrimViewModel: ObservableObject {
    internal let logger = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "trimming")
    
    // Use PlayerManager instead of direct player
    internal let playerManager = PlayerManager()
    
    // Player accessor for view layer
    var player: AVPlayer {
        return playerManager.player ?? AVPlayer()
    }
    
    // Timer to update the playhead position
    internal var playheadUpdateTimer: Timer?
    
    // Asset properties
    let assetURL: URL
    let assetDuration: CMTime
    let startOffsetTime: CMTime
    
    // Trimming properties
    @Published var isPlaying = false
    @Published var shouldShowPlayButton = true
    @Published var currentTime: CMTime
    @Published var startTrimTime: CMTime
    @Published var endTrimTime: CMTime
    @Published var isSaving = false
    @Published var error: Error?
    @Published var successMessage: String? = nil
    
    // Loading state
    @Published var isLoading = false
    @Published var downloadProgress: Double = 0.0
    
    // Thumbnails for timeline
    @Published var thumbnails: [UIImage?] = []
    
    // Handle dragging state 
    @Published var isDraggingLeftHandle = false
    @Published var isDraggingRightHandle = false
    
    // Track which handle was last dragged
    internal var lastDraggedRightHandle = false
    
    // Local video URL
    internal var localVideoURL: URL?
    
    // Managers and services
    internal let trimManager = VideoTrimManager()
    internal var timelineManager: TimelineManager!
    internal let audioSessionManager = AudioSessionManager()
    internal let exportService = VideoExportService()
    
    init(assetURL: URL, currentPlaybackTime: CMTime, duration: CMTime) {
        self.assetURL = assetURL
        self.assetDuration = duration
        self.startOffsetTime = currentPlaybackTime
        
        // Initialize logging
        logger.debug("VideoTrimViewModel initializing with URL: \(assetURL.absoluteString)")
        logger.debug("Asset exists: \(FileManager.default.fileExists(atPath: assetURL.path))")
        logger.debug("Asset duration: \(duration.seconds) seconds")
        
        // Set initial values for trimming
        self.currentTime = currentPlaybackTime
        
        // TikTok-style trimming: Start handle near beginning, but not at the edge
        let totalDuration = CMTimeGetSeconds(duration)
        
        // Use current playback time for left handle position
        let currentTimeSeconds = CMTimeGetSeconds(currentPlaybackTime)
        let startTimeSeconds = currentTimeSeconds
        self.startTrimTime = CMTime(seconds: startTimeSeconds, preferredTimescale: 600)
        
        // End handle should be 60s forward (or at end of asset)
        let selectionDuration = min(60.0, totalDuration - startTimeSeconds)
        let endTimeSeconds = startTimeSeconds + selectionDuration
        self.endTrimTime = CMTime(seconds: endTimeSeconds, preferredTimescale: 600)
        
        logger.debug("Trim time window: \(startTimeSeconds) to \(endTimeSeconds) seconds")
        
        // Initialize player with a unique audio configuration
        let asset = AVAsset(url: assetURL)
        let playerItem = AVPlayerItem(asset: asset)
        
        // Configure player manager
        playerManager.createNewPlayer(from: asset, url: assetURL)
        
        // Configure audio session for trimming
        playerManager.setupAudioSession(forTrimming: true)
        
        // Set up player observation
        setupPlayerObservation()
        
        // Initialize timeline manager after properties are set
        self.timelineManager = TimelineManager(
            startTrimTime: startTrimTime,
            endTrimTime: endTrimTime,
            currentTime: currentTime,
            assetDuration: duration
        )
        
        // Setup timeline manager callbacks
        timelineManager.onUpdateStartTime = { [weak self] newTime in
            self?.startTrimTime = newTime
        }
        
        timelineManager.onUpdateEndTime = { [weak self] newTime in
            self?.endTrimTime = newTime
        }
        
        timelineManager.onSeekToTime = { [weak self] time in
            self?.seekToTime(time)
        }
        
        // Seek to start trim time but don't play automatically
        seekToTime(startTrimTime)
        
        // We will set up the time observer when playback starts, not here
        // This avoids potential race conditions during initialization
    }
    
    private func setupPlayerObservation() {
        // Observe player isPlaying state
        Task {
            for await isPlaying in playerManager.$isPlaying.values {
                self.isPlaying = isPlaying
            }
        }
    }
    
    deinit {
        logger.debug("VideoTrimViewModel deinit called")
        
        // We must not use Task here - it can cause a race condition since deinit is synchronous
        // but the Task might run after object is deallocated
        
        // NOTE: We're intentionally NOT cleaning up the player or observer here
        // as that's handled explicitly by prepareForDismissal()
    }
}