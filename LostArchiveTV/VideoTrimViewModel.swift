import Foundation
import AVFoundation
import SwiftUI
import OSLog

@MainActor
class VideoTrimViewModel: ObservableObject {
    private let logger = Logger(subsystem: "com.sourcetable.LostArchiveTV", category: "trimming")
    
    // Player
    let player: AVPlayer
    
    // Asset properties
    let assetURL: URL
    let assetDuration: CMTime
    let startOffsetTime: CMTime
    
    // Trimming properties
    @Published var isTrimming = false
    @Published var isPlaying = false
    @Published var currentTime: CMTime
    @Published var startTrimTime: CMTime
    @Published var endTrimTime: CMTime
    @Published var isZoomed = false
    @Published var isSaving = false
    @Published var error: Error?
    
    // Loading state
    @Published var isLoading = false
    @Published var downloadProgress: Double = 0.0
    
    // Thumbnails for timeline
    @Published var thumbnails: [UIImage?] = []
    
    // Handle dragging state 
    @Published var isDraggingLeftHandle = false
    @Published var isDraggingRightHandle = false
    
    // Timeline view configuration
    private let defaultVisibleDuration = 90.0  // Show 90 seconds by default
    private let minimumTrimDuration = 1.0      // Minimum 1 second trim
    private var initialHandleTime: Double = 0  // For tracking drag start
    private var dragStartPos: CGFloat = 0      // Starting position of drag
    
    // Local video URL
    private var localVideoURL: URL?
    
    // Time observer token
    private var timeObserverToken: Any?
    
    // Thumbnail generator
    private var thumbnailGenerator: AVAssetImageGenerator?
    
    // Trim manager
    private let trimManager = VideoTrimManager()
    private let cacheManager = VideoCacheManager()
    
    init(assetURL: URL, currentPlaybackTime: CMTime, duration: CMTime) {
        self.assetURL = assetURL
        self.assetDuration = duration
        self.startOffsetTime = currentPlaybackTime
        
        // Initialize player with a unique audio configuration
        let playerItem = AVPlayerItem(url: assetURL)
        self.player = AVPlayer(playerItem: playerItem)
        
        // Configure a separate audio session with a different category
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            logger.debug("Set up dedicated audio session for trim view")
        } catch {
            logger.error("Failed to set up trim view audio session: \(error)")
        }
        
        // Set initial values for trimming
        self.currentTime = currentPlaybackTime
        
        // TikTok-style trimming: Start handle near beginning, but not at the edge
        // This makes it easier for users to grab the handle
        let totalDuration = CMTimeGetSeconds(duration)
        
        // Calculate start at 15% into the video from current position
        let currentTimeSeconds = CMTimeGetSeconds(currentPlaybackTime)
        // Adjust start position to be slightly offset from current position
        let startTimeSeconds = max(0, currentTimeSeconds - 1.0)
        self.startTrimTime = CMTime(seconds: startTimeSeconds, preferredTimescale: 600)
        
        // End handle should be 30s forward, creating a good default selection
        // This creates a "zoomed in" timeline view similar to TikTok
        let selectionDuration = min(30.0, totalDuration - startTimeSeconds - 1.0)
        let maxEndTimeSeconds = startTimeSeconds + selectionDuration
        
        self.endTrimTime = CMTime(seconds: maxEndTimeSeconds, preferredTimescale: 600)
        
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
    
    // Prepare for trimming by downloading if needed
    func prepareForTrimming() async {
        isLoading = true
        
        // Since we don't have a direct method to get cached URL by string,
        // let's just use the original URL for now
        // In a real implementation we would check the cache properly
        
        // Just proceed with direct downloading
        localVideoURL = nil
        
        // Download the video to a local file
        logger.debug("Downloading video for trimming: \(self.assetURL)")
        
        do {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("trim_\(UUID().uuidString)")
                .appendingPathExtension("mp4")
            
            // Create a download task
            let downloadTask = URLSession.shared.downloadTask(with: assetURL) { [weak self] tempFileURL, response, error in
                guard let self = self else { return }
                
                if let error = error {
                    logger.error("Download failed: \(error.localizedDescription)")
                    Task { @MainActor in
                        self.error = error
                        self.isLoading = false
                    }
                    return
                }
                
                guard let tempFileURL = tempFileURL else {
                    logger.error("No file URL in download response")
                    Task { @MainActor in
                        self.error = NSError(domain: "VideoTrimming", code: 1, userInfo: [NSLocalizedDescriptionKey: "Download failed with no file"])
                        self.isLoading = false
                    }
                    return
                }
                
                do {
                    // Move the temp file to our target location
                    try FileManager.default.moveItem(at: tempFileURL, to: tempURL)
                    logger.debug("Download complete, moved to: \(tempURL)")
                    
                    Task { @MainActor in
                        self.localVideoURL = tempURL
                        self.isLoading = false
                        
                        // Update player with local file
                        let asset = AVAsset(url: tempURL)
                        let playerItem = AVPlayerItem(asset: asset)
                        self.player.replaceCurrentItem(with: playerItem)
                        
                        // Seek to the start trim time
                        self.seekToTime(self.startTrimTime)
                        
                        // Generate thumbnails
                        self.generateThumbnails(from: asset)
                    }
                } catch {
                    logger.error("Failed to move download: \(error.localizedDescription)")
                    Task { @MainActor in
                        self.error = error
                        self.isLoading = false
                    }
                }
            }
            
            // Track download progress
            downloadTask.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.downloadProgress = progress.fractionCompleted
                }
            }
            
            downloadTask.resume()
            
        } catch {
            logger.error("Failed to prepare for downloading: \(error.localizedDescription)")
            self.error = error
            isLoading = false
        }
    }
    
    // Call this before dismissing the view
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
        do {
            // Deactivate our audio session
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            logger.debug("Deactivated trim view audio session")
        } catch {
            logger.error("Failed to deactivate trim view audio session: \(error)")
        }
        
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
    
    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time
            
            // Loop back to start trim time if we reach the end trim time
            if CMTimeCompare(time, self.endTrimTime) >= 0 {
                self.seekToTime(self.startTrimTime)
            }
        }
    }
    
    func togglePlayback() {
        isPlaying.toggle()
        if isPlaying {
            player.play()
        } else {
            player.pause()
        }
    }
    
    func seekToTime(_ time: CMTime) {
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    func updateStartTrimTime(_ newStartTime: CMTime) {
        // Ensure start time is within valid bounds (not before 0, not after end time)
        let validStartTime = max(CMTime.zero, newStartTime)
        
        // Minimum trim duration is 1 second
        let minimumDuration = CMTime(seconds: 1.0, preferredTimescale: 600)
        let latestPossibleStart = CMTimeSubtract(endTrimTime, minimumDuration)
        
        // Apply the valid start time
        if CMTimeCompare(validStartTime, latestPossibleStart) <= 0 {
            startTrimTime = validStartTime
            
            // If current time is before new start time, seek to start time
            if CMTimeCompare(currentTime, startTrimTime) < 0 {
                seekToTime(startTrimTime)
            }
        }
    }
    
    func updateEndTrimTime(_ newEndTime: CMTime) {
        // Ensure end time is within valid bounds (not after duration, not before start time)
        let validEndTime = min(assetDuration, newEndTime)
        
        // Minimum trim duration is 1 second
        let minimumDuration = CMTime(seconds: 1.0, preferredTimescale: 600)
        let earliestPossibleEnd = CMTimeAdd(startTrimTime, minimumDuration)
        
        // Apply the valid end time
        if CMTimeCompare(validEndTime, earliestPossibleEnd) >= 0 {
            endTrimTime = validEndTime
            
            // If current time is after new end time, seek to start time
            if CMTimeCompare(currentTime, endTrimTime) > 0 {
                seekToTime(startTrimTime)
            }
        }
    }
    
    func toggleZoom() {
        isZoomed.toggle()
    }
    
    // MARK: - Timeline Calculations
    
    /// Calculate the visible time window for timeline display
    func calculateVisibleTimeWindow() -> (start: Double, end: Double) {
        let visibleDuration = min(defaultVisibleDuration, assetDuration.seconds)
        
        // Center around the trimmed section
        let trimMiddle = (startTrimTime.seconds + endTrimTime.seconds) / 2.0
        
        // Calculate start and end of window
        var timelineStart = max(0, trimMiddle - visibleDuration / 2)
        
        // Ensure we don't go past the end of the video
        if timelineStart + visibleDuration > assetDuration.seconds {
            timelineStart = max(0, assetDuration.seconds - visibleDuration)
        }
        
        let timelineEnd = min(assetDuration.seconds, timelineStart + visibleDuration)
        
        return (timelineStart, timelineEnd)
    }
    
    /// Convert a time value to a position in the timeline (in pixels)
    func timeToPosition(timeInSeconds: Double, timelineWidth: CGFloat) -> CGFloat {
        let timeWindow = calculateVisibleTimeWindow()
        let visibleDuration = timeWindow.end - timeWindow.start
        let pixelsPerSecond = timelineWidth / visibleDuration
        
        return (timeInSeconds - timeWindow.start) * pixelsPerSecond
    }
    
    /// Convert a position in the timeline to time value
    func positionToTime(position: CGFloat, timelineWidth: CGFloat) -> Double {
        let timeWindow = calculateVisibleTimeWindow()
        let visibleDuration = timeWindow.end - timeWindow.start
        let secondsPerPixel = visibleDuration / timelineWidth
        
        let timeInSeconds = timeWindow.start + (position * secondsPerPixel)
        return max(0, min(timeInSeconds, assetDuration.seconds))
    }
    
    // MARK: - Handle Dragging
    
    /// Start dragging the left (start) handle
    func startLeftHandleDrag(position: CGFloat) {
        isDraggingLeftHandle = true
        dragStartPos = position
        initialHandleTime = startTrimTime.seconds
    }
    
    /// Process left handle drag
    func updateLeftHandleDrag(currentPosition: CGFloat, timelineWidth: CGFloat) {
        // Calculate drag distance in pixels
        let dragDelta = currentPosition - dragStartPos
        
        // Calculate time window and pixels per second
        let timeWindow = calculateVisibleTimeWindow()
        let visibleDuration = timeWindow.end - timeWindow.start
        let secondsPerPixel = visibleDuration / timelineWidth
        
        // Convert drag distance to time delta
        let timeDelta = dragDelta * secondsPerPixel
        
        // Calculate new time and apply constraints
        let newStartTime = initialHandleTime + timeDelta
        let maxStartTime = endTrimTime.seconds - minimumTrimDuration
        let clampedTime = max(0, min(newStartTime, maxStartTime))
        
        // Update start trim time
        let newTime = CMTime(seconds: clampedTime, preferredTimescale: 600)
        updateStartTrimTime(newTime)
    }
    
    /// End left handle drag
    func endLeftHandleDrag() {
        isDraggingLeftHandle = false
    }
    
    /// Start dragging the right (end) handle
    func startRightHandleDrag(position: CGFloat) {
        isDraggingRightHandle = true
        dragStartPos = position
        initialHandleTime = endTrimTime.seconds
    }
    
    /// Process right handle drag
    func updateRightHandleDrag(currentPosition: CGFloat, timelineWidth: CGFloat) {
        // Calculate drag distance in pixels
        let dragDelta = currentPosition - dragStartPos
        
        // Calculate time window and pixels per second
        let timeWindow = calculateVisibleTimeWindow()
        let visibleDuration = timeWindow.end - timeWindow.start
        let secondsPerPixel = visibleDuration / timelineWidth
        
        // Convert drag distance to time delta
        let timeDelta = dragDelta * secondsPerPixel
        
        // Calculate new time and apply constraints
        let newEndTime = initialHandleTime + timeDelta
        let minEndTime = startTrimTime.seconds + minimumTrimDuration
        let clampedTime = min(assetDuration.seconds, max(newEndTime, minEndTime))
        
        // Update end trim time
        let newTime = CMTime(seconds: clampedTime, preferredTimescale: 600)
        updateEndTrimTime(newTime)
    }
    
    /// End right handle drag
    func endRightHandleDrag() {
        isDraggingRightHandle = false
    }
    
    /// Handle timeline scrubbing
    func scrubTimeline(position: CGFloat, timelineWidth: CGFloat) {
        let timeInSeconds = positionToTime(position: position, timelineWidth: timelineWidth)
        let newTime = CMTime(seconds: timeInSeconds, preferredTimescale: 600)
        seekToTime(newTime)
    }
    
    // Generate thumbnails from the video asset
    private func generateThumbnails(from asset: AVAsset) {
        // Pre-allocate array with placeholders
        let count = 20 // Number of thumbnails to generate (more for better visual)
        thumbnails = Array(repeating: nil, count: count)
        
        // Use our trim manager to generate thumbnails
        trimManager.generateThumbnails(from: asset, count: count) { [weak self] (images: [UIImage]) in
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
    
    func saveTrimmmedVideo() async {
        isSaving = true
        
        // Stop playback
        if isPlaying {
            player.pause()
            isPlaying = false
        }
        
        // Use the downloaded local URL if available, otherwise use asset URL
        let sourceURL = localVideoURL ?? assetURL
        
        do {
            // Return to main thread for UI updates
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                trimManager.trimVideo(url: sourceURL, startTime: startTrimTime, endTime: endTrimTime) { result in
                    switch result {
                    case .success(let outputURL):
                        self.logger.info("Trim successful. Output URL: \(outputURL)")
                        continuation.resume()
                    case .failure(let error):
                        self.logger.error("Trim failed: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    }
                }
            }
            isSaving = false
        } catch {
            self.error = error
            isSaving = false
        }
    }
}