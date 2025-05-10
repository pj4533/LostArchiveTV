import SwiftUI
import AVKit
import AVFoundation
import OSLog

/// A simplified trim view that uses a direct player instance
struct SimpleTrimView: View {
    // Asset properties from the source
    let videoURL: URL
    let initialPosition: CMTime
    let videoDuration: CMTime
    
    // Environment variables
    @Environment(\.dismiss) private var dismiss
    
    // State
    @StateObject private var viewModel = SimpleTrimViewModel()
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    // Logger
    private let logger = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "simpletrimview")
    
    var body: some View {
        ZStack {
            // Background
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Top toolbar
                HStack {
                    Button("Cancel") {
                        cleanupAndDismiss()
                    }
                    .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("Adjust clip")
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button("Save") {
                        Task {
                            await viewModel.saveTrimmmedVideo()
                            showSuccessAlert = true
                        }
                    }
                    .foregroundColor(.white)
                    .disabled(viewModel.isLoading || viewModel.isSaving)
                }
                .padding()
                
                if viewModel.isLoading {
                    Spacer()
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()

                        Text("Preparing video for trimming...")
                            .foregroundColor(.white)
                            .padding()

                        // Add a text indicator showing what's happening
                        Text("This may take a few seconds")
                            .foregroundColor(.gray)
                            .font(.caption)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                    Spacer()
                } else {
                    Spacer()
                    
                    // Player view
                    ZStack {
                        // Video player
                        if let player = viewModel.player {
                            VideoPlayer(player: player)
                                .aspectRatio(contentMode: .fit)
                                .overlay(
                                    // Add border to make player bounds visible
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(Color.blue, lineWidth: 2)
                                )
                                .background(Color.gray.opacity(0.5))
                                .onAppear {
                                    logger.debug("VideoPlayer appeared with player: \(String(describing: player))")
                                    // Create a dedicated audio session for this player
                                    let audioSession = AVAudioSession.sharedInstance()
                                    do {
                                        try audioSession.setCategory(.playback, mode: .moviePlayback, options: .duckOthers)
                                        try audioSession.setActive(true)
                                        self.logger.debug("🎬 SIMPLETRIM_VIDEO: Set up dedicated audio session for trim player")
                                    } catch {
                                        self.logger.error("🎬 SIMPLETRIM_VIDEO: Failed to set up audio session: \(error.localizedDescription)")
                                    }

                                    // Try to force player to be visible by playing immediately
                                    logger.debug("🎬 SIMPLETRIM_VIDEO: Attempting to force player visibility by quick play/pause")
                                    player.play()
                                    // Give it a longer pause delay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        player.pause()
                                        self.logger.debug("🎬 SIMPLETRIM_VIDEO: Force paused player after visibility attempt")
                                    }
                                }
                        } else {
                            Text("Player not available")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.red.opacity(0.5))
                                .cornerRadius(8)
                        }
                        
                        // Play button overlay
                        if viewModel.shouldShowPlayButton {
                            Button(action: {
                                viewModel.togglePlayback()
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.black.opacity(0.3))
                                        .frame(width: 80, height: 80)
                                        
                                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.white)
                                        .shadow(radius: 3)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Trim controls
                    VStack {
                        // Time display
                        HStack {
                            Text(formatTime(viewModel.startTime.seconds))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text("\(formatDuration(from: viewModel.startTime, to: viewModel.endTime)) selected")
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text(formatTime(viewModel.endTime.seconds))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal)
                        
                        // Simplified timeline with slider
                        HStack {
                            Button(action: { 
                                viewModel.trimInPoint()
                            }) {
                                Image(systemName: "arrow.right.to.line")
                                    .foregroundColor(.white)
                            }
                            .frame(width: 44, height: 44)
                            
                            Slider(
                                value: $viewModel.sliderPosition,
                                in: 0...1,
                                onEditingChanged: { editing in
                                    viewModel.sliderDragging(isEditing: editing, position: viewModel.sliderPosition)
                                }
                            )
                            .accentColor(.white)
                            
                            Button(action: { 
                                viewModel.trimOutPoint()
                            }) {
                                Image(systemName: "arrow.left.to.line")
                                    .foregroundColor(.white)
                            }
                            .frame(width: 44, height: 44)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    }
                }
            }
        }
        .alert("Video Saved", isPresented: $showSuccessAlert) {
            Button("OK") {
                cleanupAndDismiss()
            }
        } message: {
            Text("Your trimmed video has been successfully saved to Photos.")
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") {
                showErrorAlert = false
            }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            Task {
                // Initialize the player with our asset URL
                await viewModel.initialize(videoURL: videoURL, initialPosition: initialPosition, duration: videoDuration)
            }
        }
    }
    
    private func cleanupAndDismiss() {
        logger.debug("🧹 SIMPLETRIM_CLEANUP: Starting cleanup and dismissing trim view")

        // Log player state before cleanup
        if let player = viewModel.player {
            let playerPointer = String(describing: ObjectIdentifier(player))
            let itemStatus = player.currentItem?.status.rawValue ?? -1
            let isPlaying = player.rate > 0
            logger.debug("🧹 SIMPLETRIM_CLEANUP: Player before cleanup - ID: \(playerPointer), status: \(itemStatus), playing: \(isPlaying)")
        } else {
            logger.debug("🧹 SIMPLETRIM_CLEANUP: No player to clean up (already nil)")
        }

        // Perform cleanup
        viewModel.cleanup()

        // Log after cleanup
        logger.debug("🧹 SIMPLETRIM_CLEANUP: Cleanup completed, player is now nil, dismissing view")

        // Dismiss the view
        dismiss()
    }
    
    // Formatter utilities
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
    
    private func formatDuration(from start: CMTime, to end: CMTime) -> String {
        let durationSeconds = end.seconds - start.seconds
        return "\(String(format: "%.1f", durationSeconds))s"
    }
}

/// A simple view model for the trim view
class SimpleTrimViewModel: ObservableObject {
    // Player and playback properties
    @Published var player: AVPlayer?
    @Published var isPlaying = false
    @Published var isLoading = true
    @Published var isSaving = false
    @Published var shouldShowPlayButton = true
    
    // Trim properties
    @Published var startTime: CMTime = .zero
    @Published var currentTime: CMTime = .zero
    @Published var endTime: CMTime = .zero
    @Published var sliderPosition: Double = 0.0
    
    // Asset properties
    private var videoURL: URL?
    private var asset: AVAsset?
    private var assetDuration: CMTime = .zero
    
    // Managers
    private let logger = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "simpletrimviewmodel")
    private let trimManager = VideoTrimManager()
    
    // Time observer
    private var timeObserver: Any?
    
    /// Initialize the player with the video URL
    func initialize(videoURL: URL, initialPosition: CMTime, duration: CMTime) async {
        self.isLoading = true
        self.videoURL = videoURL
        self.assetDuration = duration

        logger.debug("🎬 SIMPLETRIM_INIT: Starting initialization with URL: \(videoURL.lastPathComponent), position: \(initialPosition.seconds), duration: \(duration.seconds)")

        do {
            // Create and load the asset
            let asset = AVURLAsset(url: videoURL)
            logger.debug("🎬 SIMPLETRIM_INIT: Created asset, loading properties")
            try await asset.load(.isPlayable, .duration, .tracks)
            self.asset = asset

            // Create unique identifiers for logging
            let assetID = String(describing: ObjectIdentifier(asset))
            logger.debug("🎬 SIMPLETRIM_INIT: Asset loaded successfully with ID \(assetID)")

            // Simple trim setup - start from initial position, allow 30 seconds or to the end
            let startSeconds = initialPosition.seconds
            let endSeconds = min(startSeconds + 30.0, duration.seconds)

            self.startTime = CMTime(seconds: startSeconds, preferredTimescale: 600)
            self.currentTime = CMTime(seconds: startSeconds, preferredTimescale: 600)
            self.endTime = CMTime(seconds: endSeconds, preferredTimescale: 600)

            logger.debug("🎬 SIMPLETRIM_INIT: Set trim boundaries - start: \(startSeconds)s, end: \(endSeconds)s")

            // First attempt to directly load the URL which is most reliable
            logger.debug("🎬 SIMPLETRIM_INIT: Creating player directly from file URL: \(videoURL.path)")

            // Set up audio session specifically for this player
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playback, mode: .moviePlayback, options: .duckOthers)
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                logger.debug("🎬 SIMPLETRIM_INIT: Set up dedicated audio session for trim player")
            } catch {
                logger.error("🎬 SIMPLETRIM_INIT: Failed to set up audio session: \(error.localizedDescription)")
            }

            // Create a new player item with specific options for better loading
            let playerItemOpts = [AVURLAssetPreferPreciseDurationAndTimingKey: true]
            let newAsset = AVURLAsset(url: videoURL, options: playerItemOpts)
            let playerItem = AVPlayerItem(asset: newAsset)
            let playerItemID = String(describing: ObjectIdentifier(playerItem))
            logger.debug("🎬 SIMPLETRIM_INIT: Created player item with ID \(playerItemID), initial status: \(playerItem.status.rawValue)")

            // Create the player with the observed item
            let player = AVPlayer(playerItem: playerItem)
            let playerID = String(describing: ObjectIdentifier(player))
            logger.debug("🎬 SIMPLETRIM_INIT: Created player with ID \(playerID)")

            // Configure player for best experience
            player.automaticallyWaitsToMinimizeStalling = false
            player.actionAtItemEnd = .pause
            player.allowsExternalPlayback = false
            player.preventsDisplaySleepDuringVideoPlayback = true
            logger.debug("🎬 SIMPLETRIM_INIT: Configured player settings with enhanced options")

            // Set up observer and assign to our published property
            logger.debug("🎬 SIMPLETRIM_INIT: Setting up time observer")
            setupTimeObserver(for: player)

            logger.debug("🎬 SIMPLETRIM_INIT: Assigning player to published property")
            self.player = player

            // Start playback to force loading
            logger.debug("🎬 SIMPLETRIM_INIT: Starting playback to force loading")
            player.play()

            // Wait for the player to load, but with a timeout
            for attempt in 1...10 {
                logger.debug("🎬 SIMPLETRIM_LOAD: Waiting for player to be ready - attempt \(attempt)")

                if playerItem.status == .readyToPlay {
                    logger.debug("🎬 SIMPLETRIM_LOAD: Player item is ready to play")
                    break
                }

                // Wait a short time between checks
                try await Task.sleep(for: .milliseconds(200))

                // If this is the last attempt, restart the player to try harder
                if attempt == 5 {
                    logger.debug("🎬 SIMPLETRIM_LOAD: Half-way through attempts - restarting playback")
                    player.pause()
                    player.play()
                }
            }

            // Pause playback now that we've loaded
            logger.debug("🎬 SIMPLETRIM_LOAD: Pausing playback now that we've loaded")
            player.pause()

            // Final seek to initial position
            logger.debug("🎬 SIMPLETRIM_SEEK: Seeking to initial position: \(initialPosition.seconds)s")
            await player.seek(to: initialPosition, toleranceBefore: .zero, toleranceAfter: .zero)

            // Log player status
            logger.debug("🎬 SIMPLETRIM_READY: Player initialized. Item status: \(player.currentItem?.status.rawValue ?? -1)")

            // Set loading to false to show the player
            Task { @MainActor in
                logger.debug("🎬 SIMPLETRIM_UI: Setting isLoading=false and shouldShowPlayButton=true")
                self.isLoading = false
                self.shouldShowPlayButton = true
            }

            // Ensure we're in the right place
            logger.debug("🎬 SIMPLETRIM_SEEK: Final seek to startTime: \(self.startTime.seconds)s")
            await player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)

            // Finish setup
            self.isLoading = false
            self.shouldShowPlayButton = true
            logger.debug("🎬 SIMPLETRIM_COMPLETE: Player fully initialized: ID \(String(describing: ObjectIdentifier(player)))")

        } catch {
            logger.error("❌ SIMPLETRIM_ERROR: Failed to initialize player: \(error.localizedDescription)")
            self.isLoading = false
        }
    }
    
    /// Toggle playback state
    func togglePlayback() {
        if isPlaying {
            player?.pause()
            isPlaying = false
        } else {
            // If at the end, go back to start
            if let currentSeconds = player?.currentTime().seconds, 
               currentSeconds >= endTime.seconds {
                player?.seek(to: startTime)
            }
            
            player?.play()
            isPlaying = true
        }
        
        shouldShowPlayButton = false
    }
    
    /// Set the in point to the current position
    func trimInPoint() {
        guard let player = player else { return }
        let currentPosition = player.currentTime()
        
        // Ensure in point is before out point
        if CMTimeCompare(currentPosition, endTime) < 0 {
            startTime = currentPosition
            logger.debug("Set in point to \(self.startTime.seconds)")
        }
    }
    
    /// Set the out point to the current position
    func trimOutPoint() {
        guard let player = player else { return }
        let currentPosition = player.currentTime()
        
        // Ensure out point is after in point
        if CMTimeCompare(currentPosition, startTime) > 0 {
            endTime = currentPosition
            logger.debug("Set out point to \(self.endTime.seconds)")
        }
    }
    
    /// Handle slider dragging
    func sliderDragging(isEditing: Bool, position: Double) {
        guard let player = player, 
              let duration = player.currentItem?.duration else { return }
        
        // Convert slider position to time
        let targetSeconds = position * duration.seconds
        let targetTime = CMTime(seconds: targetSeconds, preferredTimescale: 600)
        
        // Pause while dragging
        if isEditing && isPlaying {
            player.pause()
            isPlaying = false
        }
        
        // Update position
        player.seek(to: targetTime)
        currentTime = targetTime
        
        // Show play button when dragging ends
        if !isEditing {
            shouldShowPlayButton = true
        }
    }
    
    /// Save the trimmed video to photos
    func saveTrimmmedVideo() async {
        guard let videoURL = videoURL else { return }
        
        self.isSaving = true
        
        do {
            // Use existing trim manager to handle the export
            let exportService = VideoExportService()
            let success = try await exportService.exportAndSaveVideo(
                localFileURL: videoURL,
                startTime: startTime,
                endTime: endTime
            )
            
            logger.debug("Export completed: \(success)")
            self.isSaving = false
            
        } catch {
            logger.error("Failed to save trimmed video: \(error.localizedDescription)")
            self.isSaving = false
        }
    }
    
    /// Set up time observer to track playback
    private func setupTimeObserver(for player: AVPlayer) {
        // Remove existing observer if any
        if let existingObserver = timeObserver {
            self.player?.removeTimeObserver(existingObserver)
            timeObserver = nil
        }

        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)

        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }

            // Update current time
            self.currentTime = time

            // Update slider position
            if let duration = player.currentItem?.duration, duration.seconds > 0 {
                self.sliderPosition = time.seconds / duration.seconds
            }

            // Loop playback within trim boundaries
            if CMTimeCompare(time, self.endTime) >= 0 && self.isPlaying {
                player.seek(to: self.startTime)
            }
        }

        logger.debug("Time observer set up for player")
    }
    
    /// Clean up resources
    func cleanup() {
        logger.debug("🧨 SIMPLETRIM_CLEANUP: Starting resource cleanup")

        // Log player state before cleanup
        if let player = player {
            let playerID = String(describing: ObjectIdentifier(player))
            let playerItemStatus = player.currentItem?.status.rawValue ?? -1
            let isPlaying = player.rate > 0
            logger.debug("🧨 SIMPLETRIM_CLEANUP: Cleaning up player \(playerID), item status: \(playerItemStatus), isPlaying: \(isPlaying)")
        } else {
            logger.debug("🧨 SIMPLETRIM_CLEANUP: No player to clean up (already nil)")
        }

        // Remove time observer first
        if let timeObserver = timeObserver, let player = player {
            logger.debug("🧨 SIMPLETRIM_CLEANUP: Removing time observer")
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }

        // Stop playback and clear
        if let player = player {
            // Stop the player completely
            logger.debug("🧨 SIMPLETRIM_CLEANUP: Pausing player")
            player.rate = 0
            player.pause()

            // Remove the item, force the player to release resources
            logger.debug("🧨 SIMPLETRIM_CLEANUP: Replacing player item with nil")
            player.replaceCurrentItem(with: nil)
        }

        // Release audio session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            logger.debug("🧨 SIMPLETRIM_CLEANUP: Deactivated audio session")
        } catch {
            logger.error("🧨 SIMPLETRIM_CLEANUP: Failed to deactivate audio session: \(error.localizedDescription)")
        }

        // Set player to nil last, after resources are released
        logger.debug("🧨 SIMPLETRIM_CLEANUP: Setting player property to nil")
        player = nil

        // Remove strong references to asset
        asset = nil
        videoURL = nil

        logger.debug("🧨 SIMPLETRIM_CLEANUP: All player resources cleaned up")
    }
    
    deinit {
        // Ensure cleanup happens
        logger.debug("♻️ SIMPLETRIM_DEINIT: View model being deinitialized, ensuring cleanup")
        cleanup()
        logger.debug("♻️ SIMPLETRIM_DEINIT: Cleanup completed during deinit")
    }
}