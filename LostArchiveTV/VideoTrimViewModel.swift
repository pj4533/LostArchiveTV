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
    
    // Time observer token
    private var timeObserverToken: Any?
    
    // Trim manager
    private let trimManager = VideoTrimManager()
    
    init(assetURL: URL, currentPlaybackTime: CMTime, duration: CMTime) {
        self.assetURL = assetURL
        self.assetDuration = duration
        self.startOffsetTime = currentPlaybackTime
        
        // Initialize player
        self.player = AVPlayer(url: assetURL)
        
        // Set initial values for trimming
        self.currentTime = currentPlaybackTime
        self.startTrimTime = currentPlaybackTime
        
        // Set end trim time to 1 minute after start or the end of the clip, whichever is shorter
        let oneMinute = CMTime(seconds: 60, preferredTimescale: 600)
        let remainingTime = CMTimeSubtract(duration, currentPlaybackTime)
        self.endTrimTime = CMTimeCompare(remainingTime, oneMinute) < 0 ? duration : CMTimeAdd(currentPlaybackTime, oneMinute)
        
        // Set up playback time observer
        setupTimeObserver()
        
        // Seek to start trim time
        seekToTime(startTrimTime)
    }
    
    deinit {
        logger.debug("VideoTrimViewModel deinit called")
        
        // We must not use Task here - it can cause a race condition since deinit is synchronous
        // but the Task might run after object is deallocated
        
        // NOTE: We're intentionally NOT cleaning up the player or observer here
        // as that's handled explicitly by prepareForDismissal()
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
    
    private func removeTimeObserver() {
        if let timeObserverToken = timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
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
        // Ensure start time is not after end time
        if CMTimeCompare(newStartTime, endTrimTime) < 0 {
            startTrimTime = newStartTime
            
            // If current time is before new start time, seek to start time
            if CMTimeCompare(currentTime, startTrimTime) < 0 {
                seekToTime(startTrimTime)
            }
        }
    }
    
    func updateEndTrimTime(_ newEndTime: CMTime) {
        // Ensure end time is not before start time
        if CMTimeCompare(newEndTime, startTrimTime) > 0 {
            endTrimTime = newEndTime
            
            // If current time is after new end time, seek to start time
            if CMTimeCompare(currentTime, endTrimTime) > 0 {
                seekToTime(startTrimTime)
            }
        }
    }
    
    func toggleZoom() {
        isZoomed.toggle()
    }
    
    func saveTrimmmedVideo() async {
        isSaving = true
        
        // Stop playback
        if isPlaying {
            player.pause()
            isPlaying = false
        }
        
        do {
            // Return to main thread for UI updates
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                trimManager.trimVideo(url: assetURL, startTime: startTrimTime, endTime: endTrimTime) { result in
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
    
    func cancelTrimming() {
        logger.debug("Trim operation canceled - cleaning up resources")
        
        // Call our explicit cleanup method
        prepareForDismissal()
    }
}