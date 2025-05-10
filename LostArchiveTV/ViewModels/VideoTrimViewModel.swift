import Foundation
import AVFoundation
import SwiftUI
import OSLog
import Photos

// Structure to hold player settings so we can restore them after trim mode
struct PlayerSettings {
    let automaticallyWaitsToMinimizeStalling: Bool
    let preventsDisplaySleepDuringVideoPlayback: Bool
    let actionAtItemEnd: AVPlayer.ActionAtItemEnd
}

@MainActor
class VideoTrimViewModel: ObservableObject {
    internal let logger = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "trimming")

    // Use the shared player system from VideoPlaybackManager passed in from parent
    let playbackManager: VideoPlaybackManager

    // Store original player settings to restore when done
    internal var originalPlayerSettings: PlayerSettings?

    // Player accessor for view layer
    var player: AVPlayer {
        return playbackManager.player ?? AVPlayer()
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
    
    init(assetURL: URL, currentPlaybackTime: CMTime, duration: CMTime, playbackManager: VideoPlaybackManager) {
        self.assetURL = assetURL
        self.assetDuration = duration
        self.startOffsetTime = currentPlaybackTime
        self.playbackManager = playbackManager
        
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
        
        // Only configure audio session here, player initialization happens in prepareForTrimming
        // Configure audio session for trimming
        audioSessionManager.configureForPlayback()
        
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
        
        timelineManager.onSeekToTime = { [weak self] time, fromHandleDrag in
            self?.seekToTime(time, fromHandleDrag: fromHandleDrag)
        }
        
        // Don't seek here - we'll seek after player is created in prepareForTrimming
    }
    
    deinit {
        logger.debug("trim: VideoTrimViewModel deinit called - skipping auto-cleanup")
        
        // We must not use Task here - it can cause a race condition since deinit is synchronous
        // but the Task might run after object is deallocated
        
        // We can't clean up the player here because the directPlayer property is @MainActor isolated
        // This is why we need to explicitly call prepareForDismissal() from the UI layer
        NotificationCenter.default.removeObserver(self)
    }
}