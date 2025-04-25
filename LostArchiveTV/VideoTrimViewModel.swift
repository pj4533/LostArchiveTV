import Foundation
import AVFoundation
import SwiftUI
import OSLog
import Photos

@MainActor
class VideoTrimViewModel: ObservableObject {
    private let logger = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "trimming")
    
    // Use PlayerManager instead of direct player
    private let playerManager = PlayerManager()
    
    // Player accessor for view layer
    var player: AVPlayer {
        return playerManager.player ?? AVPlayer()
    }
    
    // Timer to update the playhead position
    private var playheadUpdateTimer: Timer?
    
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
    private var lastDraggedRightHandle = false
    
    // Local video URL
    private var localVideoURL: URL?
    
    // Managers and services
    private let trimManager = VideoTrimManager()
    private var timelineManager: TimelineManager!
    private let audioSessionManager = AudioSessionManager()
    private let exportService = VideoExportService()
    
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

// MARK: - Initialization and Cleanup
extension VideoTrimViewModel {
    /// Use the already downloaded file to initialize trim view
    func prepareForTrimming() async {
        logger.debug("prepareForTrimming started")
        isLoading = true
        
        do {
            // Verify the file exists and has content
            logger.debug("Checking file at path: \(self.assetURL.path)")
            if !FileManager.default.fileExists(atPath: self.assetURL.path) {
                logger.error("File does not exist at path: \(self.assetURL.path)")
                throw NSError(domain: "VideoTrimming", code: 5, userInfo: [
                    NSLocalizedDescriptionKey: "Downloaded file not found at: \(self.assetURL.path)"
                ])
            }
            
            let attributes = try FileManager.default.attributesOfItem(atPath: self.assetURL.path)
            let fileSize = attributes[.size] as? UInt64 ?? 0
            logger.info("Using local file for trimming. File size: \(fileSize) bytes")
            
            if fileSize == 0 {
                logger.error("File is empty (0 bytes)")
                throw NSError(domain: "VideoTrimming", code: 6, userInfo: [
                    NSLocalizedDescriptionKey: "Video file is empty (0 bytes)"
                ])
            }
            
            // Save the URL for later use
            self.localVideoURL = self.assetURL
            
            // Initialize player with the asset
            logger.debug("Creating AVAsset from URL: \(self.assetURL.absoluteString)")
            let asset = AVAsset(url: self.assetURL)
            
            // Create a new player with the asset
            logger.debug("Creating player item and player")
            playerManager.createNewPlayer(from: asset, url: self.assetURL)
            
            // Seek to the start trim time
            logger.debug("Seeking to start time: \(self.startTrimTime.seconds) seconds")
            self.seekToTime(self.startTrimTime)
            
            // Generate thumbnails
            logger.debug("Starting thumbnail generation")
            self.generateThumbnails(from: asset)
            
            // Update UI
            logger.debug("Setting isLoading = false")
            self.isLoading = false
            // Reset play button visibility
            self.shouldShowPlayButton = true
            
        } catch {
            logger.error("Failed to prepare trim view: \(error.localizedDescription)")
            self.error = error
            self.isLoading = false
        }
    }
    
    /// Call this before dismissing the view
    func prepareForDismissal() {
        logger.debug("Preparing trim view for dismissal")
        
        // First make sure playback is stopped
        if isPlaying {
            playerManager.pause()
            isPlaying = false
        }
        
        // Stop the playhead update timer
        stopPlayheadUpdateTimer()
        
        // Clean up player using PlayerManager
        playerManager.cleanupPlayer()
        
        // Reset audio session
        playerManager.deactivateAudioSession()
        
        // Clean up any downloaded temp files if not saved
        if let localURL = localVideoURL, !isSaving {
            // Only delete if it's in the temp directory
            if localURL.absoluteString.contains(FileManager.default.temporaryDirectory.absoluteString) {
                try? FileManager.default.removeItem(at: localURL)
                logger.debug("Removed temporary video file: \(localURL)")
            }
        }
        
        logger.debug("Trim view clean-up complete")
    }
}

// MARK: - Playback Control
extension VideoTrimViewModel {
    
    func togglePlayback() {
        isPlaying.toggle()
        
        if isPlaying {
            // Start the playhead update timer when playing
            startPlayheadUpdateTimer()
            
            // If right handle was the last one dragged, always start from the left handle
            if lastDraggedRightHandle {
                lastDraggedRightHandle = false // Reset flag once used
                seekToTime(startTrimTime)
                // Also explicitly start playback here instead of relying only on the seek completion handler
                playerManager.play()
                return
            }
            
            // Otherwise, check if current time is within trim bounds
            let currentPlayerTime = player.currentTime()
            
            if CMTimeCompare(currentPlayerTime, startTrimTime) < 0 || 
               CMTimeCompare(currentPlayerTime, endTrimTime) > 0 {
                // If outside trim bounds, seek to start and play from there
                seekToTime(startTrimTime)
                // Also explicitly start playback here
                playerManager.play()
            } else {
                // Otherwise just play from current position
                playerManager.play()
            }
        } else {
            // Stop the timer when paused
            stopPlayheadUpdateTimer()
            playerManager.pause()
        }
        
        // Show the play button again when interacting with the timeline, dragging handles, or tapping the video
        // This is handled in the UI layer by setting shouldShowPlayButton = false when button is tapped
    }
    
    // Use a simple timer to update the playhead position during playback
    private func startPlayheadUpdateTimer() {
        // Stop any existing timer first
        stopPlayheadUpdateTimer()
        
        // Create a timer that fires 10 times per second
        playheadUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, self.isPlaying, let player = self.playerManager.player else { return }
            
            // Update our currentTime property with the player's current time
            let time = player.currentTime()
            self.currentTime = time
            
            // Check if we've reached the end of the trim range
            if CMTimeCompare(time, self.endTrimTime) >= 0 {
                self.logger.debug("Reached end of trim section, looping back")
                self.seekToTime(self.startTrimTime)
            }
        }
    }
    
    private func stopPlayheadUpdateTimer() {
        playheadUpdateTimer?.invalidate()
        playheadUpdateTimer = nil
    }
    
    func seekToTime(_ time: CMTime) {
        // Update currentTime immediately so the playhead updates right away
        self.currentTime = time
        
        // Seek with completion handler to ensure operation finishes
        playerManager.seek(to: time) { [weak self] completed in
            guard let self = self, completed else { return }
            
            // If player is already in playing state, ensure it's actually playing
            if self.isPlaying {
                self.playerManager.play()
            }
        }
    }
}

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

// MARK: - Handle Dragging
extension VideoTrimViewModel {
    func startLeftHandleDrag(position: CGFloat) {
        // Pause playback if currently playing
        if isPlaying {
            playerManager.pause()
            isPlaying = false
        }
        
        // Show play button when interacting with handles
        shouldShowPlayButton = true
        
        timelineManager.startLeftHandleDrag(position: position)
        isDraggingLeftHandle = timelineManager.isDraggingLeftHandle
    }
    
    func updateLeftHandleDrag(currentPosition: CGFloat, timelineWidth: CGFloat) {
        timelineManager.updateLeftHandleDrag(currentPosition: currentPosition, timelineWidth: timelineWidth)
        // Update current time to follow the handle position
        self.currentTime = self.startTrimTime
    }
    
    func endLeftHandleDrag() {
        timelineManager.endLeftHandleDrag()
        isDraggingLeftHandle = timelineManager.isDraggingLeftHandle
        lastDraggedRightHandle = false
    }
    
    func startRightHandleDrag(position: CGFloat) {
        // Pause playback if currently playing
        if isPlaying {
            playerManager.pause()
            isPlaying = false
        }
        
        // Show play button when interacting with handles
        shouldShowPlayButton = true
        
        timelineManager.startRightHandleDrag(position: position)
        isDraggingRightHandle = timelineManager.isDraggingRightHandle
    }
    
    func updateRightHandleDrag(currentPosition: CGFloat, timelineWidth: CGFloat) {
        timelineManager.updateRightHandleDrag(currentPosition: currentPosition, timelineWidth: timelineWidth)
        // Update current time to follow the handle position
        self.currentTime = self.endTrimTime
    }
    
    func endRightHandleDrag() {
        timelineManager.endRightHandleDrag()
        isDraggingRightHandle = timelineManager.isDraggingRightHandle
        lastDraggedRightHandle = true
    }
    
    func scrubTimeline(position: CGFloat, timelineWidth: CGFloat) {
        // Pause playback if currently playing
        if isPlaying {
            playerManager.pause()
            isPlaying = false
        }
        
        // Show play button when interacting with timeline
        shouldShowPlayButton = true
        
        // Get the time for this position
        let newTimeSeconds = timelineManager.positionToTime(position: position, timelineWidth: timelineWidth)
        
        // Constrain to trim bounds
        let constrainedTime = max(startTrimTime.seconds, min(endTrimTime.seconds, newTimeSeconds))
        
        // Create CMTime
        let newTime = CMTime(seconds: constrainedTime, preferredTimescale: 600)
        
        // Update our current time directly
        self.currentTime = newTime
        
        // Send to timeline manager
        timelineManager.scrubTimeline(position: position, timelineWidth: timelineWidth)
        
        // When user manually scrubs timeline, reset the handle drag tracking
        lastDraggedRightHandle = false
    }
}

// MARK: - Thumbnail Generation
extension VideoTrimViewModel {
    /// Generate thumbnails from the video asset
    private func generateThumbnails(from asset: AVAsset) {
        // Calculate appropriate number of thumbnails based on video duration
        // We'll aim for roughly 1 thumbnail per 5 seconds of video
        let duration = assetDuration.seconds
        let idealCount = min(60, max(20, Int(ceil(duration / 5.0))))
        
        logger.debug("Generating \(idealCount) thumbnails for \(duration) second video")
        
        // Pre-allocate array with placeholders
        thumbnails = Array(repeating: nil, count: idealCount)
        
        // Use our trim manager to generate thumbnails
        trimManager.generateThumbnails(from: asset, count: idealCount) { [weak self] (images: [UIImage]) in
            guard let self = self else { return }
            
            // Switch to main thread for UI updates
            DispatchQueue.main.async {
                // Match returned images to our pre-allocated array
                for (index, image) in images.enumerated() {
                    if index < self.thumbnails.count {
                        self.thumbnails[index] = image
                    }
                }
                
                self.logger.debug("Generated \(images.count) thumbnails for trim interface")
            }
        }
    }
}

// MARK: - Video Export
extension VideoTrimViewModel {
    /// Save the trimmed video
    func saveTrimmmedVideo() async -> Bool {
        isSaving = true
        
        // Stop playback
        if isPlaying {
            playerManager.pause()
            isPlaying = false
        }
        
        // Is a download in progress?
        if isLoading {
            self.error = NSError(domain: "VideoTrimming", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Please wait for the download to complete before saving"
            ])
            isSaving = false
            logger.warning("Attempted to save while still downloading")
            return false
        }
        
        // If localVideoURL is nil but we have assetURL, use that instead
        if localVideoURL == nil {
            logger.warning("localVideoURL is nil, using assetURL instead: \(self.assetURL.absoluteString)")
            localVideoURL = self.assetURL
        }
        
        // Check if we have a local file to trim
        guard let localURL = localVideoURL else {
            self.error = NSError(domain: "VideoTrimming", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Video download not complete. Please wait and try again."
            ])
            isSaving = false
            logger.error("Attempted to trim without a local file")
            return false
        }
        
        do {
            // Use the export service to handle the trim and save
            let success = try await exportService.exportAndSaveVideo(
                localFileURL: localURL, 
                startTime: startTrimTime, 
                endTime: endTrimTime
            )
            
            // Success! Show a success message in the view
            if success {
                logger.info("Video successfully saved to Photos")
                self.error = nil
                self.successMessage = "Video successfully saved to Photos!"
            }
            
            isSaving = false
            return success
            
        } catch {
            logger.error("Trim process failed: \(error.localizedDescription)")
            self.error = error
            isSaving = false
            return false
        }
    }
}