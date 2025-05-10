import SwiftUI
import Photos
import OSLog

struct VideoInfoOverlay: View {
    let title: String?
    let collection: String?
    let description: String?
    let identifier: String?
    
    @State private var downloadedVideoURL: URL? = nil
    @State private var showSettings = false
    
    // Logger for debugging
    private let logger = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "ui")
    
    // Reference to the view model - passed from parent
    @ObservedObject var viewModel: VideoPlayerViewModel
    
    // Track the current step in the trim workflow
    @State private var trimStep: TrimWorkflowStep = .none
    
    enum TrimWorkflowStep {
        case none        // No trim action in progress
        case downloading // Downloading video for trimming
        case trimming    // Showing trim interface
    }
    
    var body: some View {
        ZStack {
            // Bottom info panel with gradient background
            BottomInfoPanel(
                title: title,
                collection: collection,
                description: description,
                identifier: identifier,
                filename: viewModel.currentFilename,
                currentTime: viewModel.player?.currentTime().seconds,
                duration: viewModel.videoDuration,
                totalFiles: viewModel.totalFiles,
                cacheStatuses: viewModel.cacheStatuses
            )
            .id("\(viewModel.totalFiles)-\(Date())") // Force refresh periodically and when totalFiles changes
            
            // Right-side buttons
            ButtonPanel(
                viewModel: viewModel,
                showSettings: $showSettings,
                identifier: identifier,
                startTrimFlow: startTrimFlow
            )
        }
        // Single sheet with conditional content based on current step
        .sheet(isPresented: Binding<Bool>(
            get: { trimStep != .none },
            set: { if !$0 { trimStep = .none }}
        ), onDismiss: {
            // Only handle dismissal if we're not advancing to the next step
            if trimStep == .none {
                self.downloadedVideoURL = nil
                Task {
                    await viewModel.resumePlayback()
                }
            }
        }) {
            if trimStep == .downloading {
                // Download sheet
                TrimDownloadView(provider: viewModel) { downloadedURL in
                    if let url = downloadedURL {
                        // Success - move to trim step
                        logger.debug("Download successful, transitioning to trim step with URL: \(url.absoluteString)")
                        self.downloadedVideoURL = url
                        self.trimStep = .trimming
                    } else {
                        // Failed download - dismiss everything
                        logger.debug("Download failed or was cancelled, dismissing workflow")
                        self.downloadedVideoURL = nil
                        self.trimStep = .none
                    }
                }
            } else if trimStep == .trimming,
                      let downloadedURL = downloadedVideoURL,
                      let currentTime = viewModel.currentVideoTime,
                      let duration = viewModel.currentVideoDuration {
                // Trim view - now using our new coordinator approach with pause/resume
                ZStack {
                    VideoTrimView(
                        videoURL: downloadedURL,
                        currentTime: currentTime,
                        duration: duration
                    )
                }
                .onAppear {
                    // IMPORTANT: Give the trim view time to initialize its player BEFORE pausing background operations
                    Task {
                        // Brief delay to allow trim view initialization to happen first
                        try? await Task.sleep(for: .milliseconds(300))

                        Logger.caching.info("🛑 PAUSE_OPERATIONS: Pausing background operations for trim view")
                        await viewModel.pauseBackgroundOperations()

                        // Log successful pause
                        Logger.caching.info("✅ BACKGROUND_OPERATIONS: Successfully paused")
                    }
                }
                .onDisappear {
                    // Resume all background operations when trim view is dismissed
                    Task {
                        Logger.caching.info("▶️ RESUME_OPERATIONS: Resuming background operations after trim view")
                        await viewModel.resumeBackgroundOperations()
                    }
                }
            } else {
                // Fallback view (should never be seen)
                Text("Preparing...")
                    .foregroundColor(.white)
            }
        }
    }
    
    // MARK: - Actions
    
    private func startTrimFlow() {
        logger.debug("Trim button tap - starting download process")
        logger.debug("Current video URL: \(String(describing: viewModel.currentVideoURL))")
        logger.debug("Current video time: \(String(describing: viewModel.currentVideoTime))")
        logger.debug("Current video duration: \(String(describing: viewModel.currentVideoDuration))")
        
        // Pause playback
        Task {
            await viewModel.pausePlayback()
            
            // Start the trim workflow with the download step
            trimStep = .downloading
        }
    }
    
}

#Preview {
    VideoInfoOverlay(
        title: "Sample Video Title",
        collection: "avgeeks",
        description: "This is a sample description for the video that might span multiple lines when displayed in the app.",
        identifier: "sample_id",
        viewModel: VideoPlayerViewModel(favoritesManager: FavoritesManager())
    )
    .background(Color.black)
}