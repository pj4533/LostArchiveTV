import Foundation
import AVFoundation
import SwiftUI
import OSLog
import Photos

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
    @Published var successMessage: String? = nil
    
    // Loading state
    @Published var isLoading = false
    @Published var downloadProgress: Double = 0.0
    
    // Thumbnails for timeline
    @Published var thumbnails: [UIImage?] = []
    
    // Handle dragging state 
    @Published var isDraggingLeftHandle = false
    @Published var isDraggingRightHandle = false
    
    // Timeline view configuration
    private let minimumTrimDuration = 1.0      // Minimum 1 second trim
    private var initialHandleTime: Double = 0  // For tracking drag start
    private var dragStartPos: CGFloat = 0      // Starting position of drag
    
    // Fixed timeline window (calculated once at init)
    private var timelineWindowStart: Double = 0
    private var timelineWindowEnd: Double = 0
    private let paddingSeconds: Double = 15.0  // Padding before/after handles
    
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
        
        // Use current playback time for left handle position
        let currentTimeSeconds = CMTimeGetSeconds(currentPlaybackTime)
        let startTimeSeconds = currentTimeSeconds
        self.startTrimTime = CMTime(seconds: startTimeSeconds, preferredTimescale: 600)
        
        // End handle should be 60s forward (or at end of asset)
        let selectionDuration = min(60.0, totalDuration - startTimeSeconds)
        let endTimeSeconds = startTimeSeconds + selectionDuration
        self.endTrimTime = CMTime(seconds: endTimeSeconds, preferredTimescale: 600)
        
        // Calculate fixed timeline window with padding
        self.timelineWindowStart = max(0, startTimeSeconds - paddingSeconds)
        self.timelineWindowEnd = min(totalDuration, endTimeSeconds + paddingSeconds)
        
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
    
    // Use the already downloaded file to initialize trim view
    func prepareForTrimming() async {
        // We don't need to download - using the file passed in constructor
        isLoading = true
        
        do {
            // We already have the file from our initialization
            // We're using assetURL directly which should be the local file URL
            
            // Verify the file exists and has content
            if !FileManager.default.fileExists(atPath: assetURL.path) {
                throw NSError(domain: "VideoTrimming", code: 5, userInfo: [
                    NSLocalizedDescriptionKey: "Downloaded file not found at: \(assetURL.path)"
                ])
            }
            
            let attributes = try FileManager.default.attributesOfItem(atPath: assetURL.path)
            let fileSize = attributes[.size] as? UInt64 ?? 0
            logger.info("Using local file for trimming. File size: \(fileSize) bytes")
            
            if fileSize == 0 {
                throw NSError(domain: "VideoTrimming", code: 6, userInfo: [
                    NSLocalizedDescriptionKey: "Video file is empty (0 bytes)"
                ])
            }
            
            // Save the URL for later use
            self.localVideoURL = assetURL
            
            // Initialize player with the asset
            let asset = AVAsset(url: assetURL)
            let playerItem = AVPlayerItem(asset: asset)
            self.player.replaceCurrentItem(with: playerItem)
            
            // Seek to the start trim time
            self.seekToTime(self.startTrimTime)
            
            // Generate thumbnails
            self.generateThumbnails(from: asset)
            
            // Update UI
            self.isLoading = false
            
        } catch {
            logger.error("Failed to prepare trim view: \(error.localizedDescription)")
            self.error = error
            self.isLoading = false
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
    
    /// Return the fixed visible time window for timeline display (calculated once at init)
    func calculateVisibleTimeWindow() -> (start: Double, end: Double) {
        return (timelineWindowStart, timelineWindowEnd)
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
    
    func saveTrimmmedVideo() async -> Bool {
        isSaving = true
        
        // Stop playback
        if isPlaying {
            player.pause()
            isPlaying = false
        }
        
        // Is a download in progress?
        if isLoading {
            // We need to wait for the download to complete first
            self.error = NSError(domain: "VideoTrimming", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Please wait for the download to complete before saving"
            ])
            isSaving = false
            logger.warning("Attempted to save while still downloading")
            return false
        }
        
        // Check if we have a local file to trim
        guard let localURL = localVideoURL else {
            // This is likely a timing issue - the user tapped Save before download completed
            self.error = NSError(domain: "VideoTrimming", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Video download not complete. Please wait and try again."
            ])
            isSaving = false
            logger.error("Attempted to trim without a local file")
            return false
        }
        
        // Verify the local file exists
        if !FileManager.default.fileExists(atPath: localURL.path) {
            self.error = NSError(domain: "VideoTrimming", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "Local file not found. The download may have failed."
            ])
            isSaving = false
            logger.error("Local file does not exist at: \(localURL.path)")
            return false
        }
        
        // Get file size for verification
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: localURL.path)
            let fileSize = attributes[.size] as? UInt64 ?? 0
            logger.info("Trimming local file: \(localURL.path), size: \(fileSize) bytes")
            
            if fileSize == 0 {
                self.error = NSError(domain: "VideoTrimming", code: 5, userInfo: [
                    NSLocalizedDescriptionKey: "Downloaded file is empty. Please try again."
                ])
                isSaving = false
                return false
            }
        } catch {
            logger.error("Failed to get file attributes: \(error.localizedDescription)")
        }
        
        // First check for Photos permission
        var authStatus: PHAuthorizationStatus = .notDetermined
        
        // Use a separate try-catch as this is not part of our main error handling
        do {
            authStatus = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<PHAuthorizationStatus, Error>) in
                PHPhotoLibrary.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
        } catch {
            self.error = NSError(domain: "VideoTrimming", code: 5, userInfo: [
                NSLocalizedDescriptionKey: "Error checking photo permissions: \(error.localizedDescription)"
            ])
            isSaving = false
            return false
        }
        
        if authStatus != .authorized {
            self.error = NSError(domain: "VideoTrimming", code: 6, userInfo: [
                NSLocalizedDescriptionKey: "Permission to save to Photos is required. Please allow in Settings."
            ])
            isSaving = false
            logger.error("Photos permission denied")
            return false
        }
        
        do {
            // Return to main thread for UI updates
            let outputURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                trimManager.trimVideo(url: localURL, startTime: startTrimTime, endTime: endTrimTime) { result in
                    switch result {
                    case .success(let outputURL):
                        self.logger.info("Trim successful. Output URL: \(outputURL)")
                        // Successfully trimmed and saved to Photos
                        continuation.resume(returning: outputURL)
                    case .failure(let error):
                        self.logger.error("Trim failed: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            // Success! Show a success message in the view
            logger.info("Video successfully saved to Photos")
            self.error = nil
            self.successMessage = "Video successfully saved to Photos!"
            isSaving = false
            return true
            
        } catch {
            logger.error("Trim process failed: \(error.localizedDescription)")
            self.error = error
            isSaving = false
            return false
        }
    }
}