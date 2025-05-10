import SwiftUI
import AVFoundation
import AVKit
import OSLog

// MARK: - Coordinator to Manage VideoTrimViewModel Lifecycle
@MainActor
class TrimCoordinator: ObservableObject {
    @Published private(set) var viewModel: VideoTrimViewModel
    private let logger = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "trimcoordinator")

    private var isInitialized = false
    private var hasBeenDismissed = false
    private var initializationInProgress = false

    init(videoURL: URL, currentTime: CMTime, duration: CMTime, playbackManager: VideoPlaybackManager) {
        self.viewModel = VideoTrimViewModel(
            assetURL: videoURL,
            currentPlaybackTime: currentTime,
            duration: duration,
            playbackManager: playbackManager
        )
        logger.debug("🎬 TRIM_COORDINATOR: Initialized for asset: \(videoURL.lastPathComponent), using existing player")

        // Log important parameters for debugging
        logger.debug("🎬 TRIM_COORDINATOR: Current time: \(currentTime.seconds)s, duration: \(duration.seconds)s")
    }

    func prepareIfNeeded() async {
        // Prevent multiple concurrent initialization attempts
        guard !isInitialized && !initializationInProgress else {
            logger.debug("🎬 TRIM_COORDINATOR: Skipping duplicate initialization request")
            return
        }

        initializationInProgress = true
        logger.debug("🎬 TRIM_COORDINATOR: Starting view model preparation")

        do {
            // Ensure audio session is properly configured before initializing player
            logger.debug("🎬 TRIM_COORDINATOR: Configuring audio session for trim view")
            viewModel.audioSessionManager.configureForTrimming()

            // Allow a brief delay for audio session to take effect
            try? await Task.sleep(for: .milliseconds(100))

            // Prepare the view model (this initializes player and resources)
            logger.debug("🎬 TRIM_COORDINATOR: Calling view model prepareForTrimming")
            await viewModel.prepareForTrimming()

            isInitialized = true
            logger.debug("🎬 TRIM_COORDINATOR: View model successfully initialized")
        } catch {
            logger.error("❌ TRIM_COORDINATOR: Initialization failed: \(error.localizedDescription)")
        }

        // Reset in-progress flag regardless of outcome
        initializationInProgress = false
    }

    func cleanup() async {
        // Only clean up once and only if initialized
        if !hasBeenDismissed {
            logger.debug("🧹 TRIM_COORDINATOR: Starting cleanup process")

            // Perform cleanup in view model
            viewModel.prepareForDismissal()

            // Mark as dismissed to prevent duplicate cleanup
            hasBeenDismissed = true
            logger.debug("🧹 TRIM_COORDINATOR: Cleanup complete")
        } else {
            logger.debug("🧹 TRIM_COORDINATOR: Cleanup already performed, skipping")
        }
    }

    deinit {
        logger.debug("♻️ TRIM_COORDINATOR: Coordinator being deinitialized")
        // We don't need to call cleanup here as it must be called explicitly
        // from the UI layer before dismissal
    }
}

// MARK: - Main VideoTrimView
struct VideoTrimView: View {
    @StateObject var coordinator: TrimCoordinator
    @Environment(\.dismiss) private var dismiss
    private let logger = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "trimview")

    @State private var showSuccessAlert = false
    
    init(videoURL: URL, currentTime: CMTime, duration: CMTime, playbackManager: VideoPlaybackManager) {
        _coordinator = StateObject(wrappedValue: TrimCoordinator(
            videoURL: videoURL,
            currentTime: currentTime,
            duration: duration,
            playbackManager: playbackManager
        ))
    }
    
    private let thumbnailHeight: CGFloat = 50
    
    var body: some View {
        let viewModel = coordinator.viewModel
        
        ZStack {
            // Background
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Main content
            Group {
                if viewModel.isSaving {
                    // Saving progress view
                    VStack {
                        Text("Saving trimmed video")
                            .foregroundColor(.white)
                            .font(.headline)
                            .padding(.bottom, 10)
                        
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                            .padding(.bottom, 20)
                        
                        Text("This will only take a moment")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.caption)
                    }
                } else if viewModel.isLoading {
                    // Loading progress view
                    VStack {
                        Text("Preparing video for trimming")
                            .foregroundColor(.white)
                            .font(.headline)
                            .padding(.bottom, 10)

                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                            .padding(.bottom, 20)

                        Text("This will only take a moment")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.caption)
                    }
                } else {
                    VStack(spacing: 0) {
                        // Top toolbar
                        HStack {
                            Button("Cancel") {
                                Task {
                                    await coordinator.cleanup()
                                    dismiss()
                                }
                            }
                            .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text("Adjust clip")
                                .foregroundColor(.white)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Button("Save") {
                                Task {
                                    let success = await viewModel.saveTrimmmedVideo()
                                    if success {
                                        showSuccessAlert = true
                                    }
                                }
                            }
                            .foregroundColor(.white)
                            .disabled(viewModel.isLoading || viewModel.isSaving)
                        }
                        .padding()
                        
                        Spacer()
                        
                        // Simple video player with ZStack for stable layout
                        if let player = viewModel.playbackManager.player {
                            ZStack {
                                VideoPlayer(player: player)
                                    .aspectRatio(contentMode: .fit)

                                // Play button overlay with opacity change to prevent layout shifts
                                Button(action: {
                                    viewModel.togglePlayback()
                                    viewModel.shouldShowPlayButton = false
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
                                .opacity(viewModel.shouldShowPlayButton ? 1.0 : 0.0)
                                .animation(.easeInOut(duration: 0.2), value: viewModel.shouldShowPlayButton)
                            }
                        }
                        
                        Spacer()
                        
                        // Duration text
                        HStack {
                            Text(formatTime(viewModel.startTrimTime.seconds))
                                .font(.caption)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text("\(formatDuration(from: viewModel.startTrimTime, to: viewModel.endTrimTime)) selected")
                                .font(.footnote)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text(formatTime(viewModel.endTrimTime.seconds))
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                        
                        // Timeline view
                        GeometryReader { geo in
                            TimelineView(viewModel: viewModel, timelineWidth: geo.size.width)
                        }
                        .frame(height: thumbnailHeight)
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                        .padding(.top, 10)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.shouldShowPlayButton = true
                    }
                }
            }
        }
        // Error alert
        .alert("Trim Error", isPresented: Binding<Bool>(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "Unknown error")
        }
        
        // Success alert
        .alert("Video Saved", isPresented: $showSuccessAlert) {
            Button("OK") {
                Task {
                    await coordinator.cleanup()
                    dismiss()
                }
            }
        } message: {
            Text("Your trimmed video has been successfully saved to Photos!")
        }
        .onAppear {
            Task(priority: .userInitiated) {
                await coordinator.prepareIfNeeded()
                // Play button will be shown by the prepareForTrimming method when loading is complete
            }
        }
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