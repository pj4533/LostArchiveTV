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
        
        // Initialize player
        self.player = AVPlayer(url: assetURL)
        
        // Set initial values for trimming
        self.currentTime = currentPlaybackTime
        self.startTrimTime = currentPlaybackTime
        
        // Set trim selection to span most of the video by default (80%)
        let totalDuration = CMTimeGetSeconds(duration)
        // Start from the beginning of the video by default
        let startTimeSeconds = 0.0
        // End about 80% of the way through the video
        let endTimeSeconds = totalDuration * 0.8
        
        self.startTrimTime = CMTime(seconds: startTimeSeconds, preferredTimescale: 600)
        self.endTrimTime = CMTime(seconds: endTimeSeconds, preferredTimescale: 600)
        
        // Seek to start trim time and start playing immediately
        seekToTime(startTrimTime)
        
        // Set up playback time observer
        setupTimeObserver()
        
        // Start playing
        isPlaying = true
        player.play()
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