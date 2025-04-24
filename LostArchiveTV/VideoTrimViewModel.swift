import Foundation
import AVFoundation
import SwiftUI
import OSLog
import Photos

@MainActor
class VideoTrimViewModel: ObservableObject {
    private let logger = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "trimming")
    
    // Player
    let player: AVPlayer
    
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
    
    // Time observer token
    private var timeObserverToken: Any?
    
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
        
        // Initialize player with a unique audio configuration
        let asset = AVAsset(url: assetURL)
        let playerItem = AVPlayerItem(asset: asset)
        self.player = AVPlayer(playerItem: playerItem)
        
        // Configure audio session
        audioSessionManager.configureForTrimming()
        
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
        
        // Set up playback time observer
        setupTimeObserver()
    }
    
    deinit {
        logger.debug("VideoTrimViewModel deinit called")
        
        // We must not use Task here - it can cause a race condition since deinit is synchronous
        // but the Task might run after object is deallocated
        
        // NOTE: We're intentionally NOT cleaning up the player or observer here
        // as that's handled explicitly by prepareForDismissal()
    }
    
    // MARK: - Initialization and Cleanup
    
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
            
            logger.debug("Creating player item")
            let playerItem = AVPlayerItem(asset: asset)
            
            logger.debug("Replacing player's current item")
            self.player.replaceCurrentItem(with: playerItem)
            
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
            player.pause()
            isPlaying = false
        }
        
        // Safely remove observer
        if let token = timeObserverToken {
            logger.debug("Removing time observer before dismissal")
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        
        // Break any potential retain cycles
        player.replaceCurrentItem(with: nil)
        
        // Reset audio session
        audioSessionManager.deactivate()
        
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
    
    // MARK: - Playback Control
    
    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time
            self.timelineManager.updateCurrentTime(time)
            
            // If playhead is outside trim bounds, handle appropriately
            if CMTimeCompare(time, self.startTrimTime) < 0 {
                // If before start time, move to start
                self.seekToTime(self.startTrimTime)
            } else if CMTimeCompare(time, self.endTrimTime) >= 0 {
                // If at or after end time, loop back to start
                if self.isPlaying {
                    logger.info("Reached end of trimmed section - looping back to start")
                    self.seekToTime(self.startTrimTime)
                }
            }
        }
    }
    
    func togglePlayback() {
        isPlaying.toggle()
        
        if isPlaying {
            // If right handle was the last one dragged, always start from the left handle
            if lastDraggedRightHandle {
                lastDraggedRightHandle = false // Reset flag once used
                seekToTime(startTrimTime)
                // The seek completion handler will start playback
                return
            }
            
            // Otherwise, check if current time is within trim bounds
            let currentPlayerTime = player.currentTime()
            
            if CMTimeCompare(currentPlayerTime, startTrimTime) < 0 || 
               CMTimeCompare(currentPlayerTime, endTrimTime) > 0 {
                // If outside trim bounds, seek to start and play from there
                seekToTime(startTrimTime)
                // The seek completion handler will start playback
            } else {
                // Otherwise just play from current position
                player.play()
            }
        } else {
            player.pause()
        }
        
        // Show the play button again when interacting with the timeline, dragging handles, or tapping the video
        // This is handled in the UI layer by setting shouldShowPlayButton = false when button is tapped
    }
    
    func seekToTime(_ time: CMTime) {
        // Seek with completion handler to ensure operation finishes
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] completed in
            guard let self = self, completed else { return }
            
            // If player is already in playing state, ensure it's actually playing
            if self.isPlaying {
                self.player.play()
            }
        }
    }
    
    // MARK: - Timeline Delegation
    
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
    
    // MARK: - Handle Dragging
    
    func startLeftHandleDrag(position: CGFloat) {
        // Pause playback if currently playing
        if isPlaying {
            player.pause()
            isPlaying = false
        }
        
        // Show play button when interacting with handles
        shouldShowPlayButton = true
        
        timelineManager.startLeftHandleDrag(position: position)
        isDraggingLeftHandle = timelineManager.isDraggingLeftHandle
    }
    
    func updateLeftHandleDrag(currentPosition: CGFloat, timelineWidth: CGFloat) {
        timelineManager.updateLeftHandleDrag(currentPosition: currentPosition, timelineWidth: timelineWidth)
    }
    
    func endLeftHandleDrag() {
        timelineManager.endLeftHandleDrag()
        isDraggingLeftHandle = timelineManager.isDraggingLeftHandle
        lastDraggedRightHandle = false
    }
    
    func startRightHandleDrag(position: CGFloat) {
        // Pause playback if currently playing
        if isPlaying {
            player.pause()
            isPlaying = false
        }
        
        // Show play button when interacting with handles
        shouldShowPlayButton = true
        
        timelineManager.startRightHandleDrag(position: position)
        isDraggingRightHandle = timelineManager.isDraggingRightHandle
    }
    
    func updateRightHandleDrag(currentPosition: CGFloat, timelineWidth: CGFloat) {
        timelineManager.updateRightHandleDrag(currentPosition: currentPosition, timelineWidth: timelineWidth)
    }
    
    func endRightHandleDrag() {
        timelineManager.endRightHandleDrag()
        isDraggingRightHandle = timelineManager.isDraggingRightHandle
        lastDraggedRightHandle = true
    }
    
    func scrubTimeline(position: CGFloat, timelineWidth: CGFloat) {
        // Pause playback if currently playing
        if isPlaying {
            player.pause()
            isPlaying = false
        }
        
        // Show play button when interacting with timeline
        shouldShowPlayButton = true
        
        timelineManager.scrubTimeline(position: position, timelineWidth: timelineWidth)
        
        // When user manually scrubs timeline, reset the handle drag tracking
        lastDraggedRightHandle = false
    }
    
    // MARK: - Thumbnail Generation
    
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
    
    // MARK: - Video Export
    
    /// Save the trimmed video
    func saveTrimmmedVideo() async -> Bool {
        isSaving = true
        
        // Stop playback
        if isPlaying {
            player.pause()
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