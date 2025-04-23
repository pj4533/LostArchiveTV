import SwiftUI
import Photos
import OSLog

struct VideoInfoOverlay: View {
    let title: String?
    let collection: String?
    let description: String?
    let identifier: String?
    
    @State private var isDownloading = false
    @State private var downloadProgress: Float = 0
    @State private var showSaveSuccessAlert = false
    @State private var saveError: String? = nil
    @State private var downloadedVideoURL: URL? = nil
    
    // Logger for debugging
    private let logger = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "ui")
    
    // Services
    private let downloadService = VideoDownloadService()
    
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
            bottomInfoPanel
            
            // Right-side buttons
            buttonPanel
        }
        // Single sheet with conditional content based on current step
        .sheet(isPresented: Binding<Bool>(
            get: { trimStep != .none },
            set: { if !$0 { trimStep = .none }}
        ), onDismiss: {
            // Only handle dismissal if we're not advancing to the next step
            if trimStep == .none {
                self.downloadedVideoURL = nil
                viewModel.resumePlayback()
            }
        }) {
            Group {
                if trimStep == .downloading {
                    // Download sheet
                    TrimDownloadView(viewModel: viewModel) { downloadedURL in
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
                    // Trim view
                    VideoTrimView(viewModel: VideoTrimViewModel(
                        assetURL: downloadedURL,
                        currentPlaybackTime: currentTime,
                        duration: duration
                    ))
                }
            }
        }
        .alert("Video Saved", isPresented: $showSaveSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Video has been saved to your photo library.")
        }
        .alert("Error Saving Video", isPresented: Binding<Bool>(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            if let error = saveError {
                Text(error)
            }
        }
    }
    
    // MARK: - Components
    
    private var bottomInfoPanel: some View {
        VStack {
            Spacer()
            
            // Bottom overlay with title and description
            VStack(alignment: .leading, spacing: 8) {
                // Video metadata (title, collection, description)
                VideoMetadataView(
                    title: title,
                    collection: collection,
                    description: description,
                    identifier: identifier,
                    currentTime: viewModel.player?.currentTime().seconds,
                    duration: viewModel.videoDuration
                )
                
                // Swipe hint
                Text("Swipe up for next video")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
    
    private var buttonPanel: some View {
        HStack {
            Spacer() // This pushes the VStack to the right edge
            
            VStack(spacing: 12) {
                Spacer()
                
                // Trim button - starts download flow first
                OverlayButton(
                    action: startTrimFlow,
                    disabled: viewModel.currentVideoURL == nil
                ) {
                    Image(systemName: "timeline.selection")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22, height: 22)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                }
                
                // Download button with progress indicator
                ProgressOverlayButton(
                    action: { if !isDownloading { downloadVideo() } },
                    progress: downloadProgress,
                    isInProgress: isDownloading,
                    normalIcon: "square.and.arrow.down.fill"
                )
                
                // Archive.org link button
                ArchiveButton(identifier: identifier)
            }
            .padding(.trailing, 8)
        }
    }
    
    // MARK: - Actions
    
    private func startTrimFlow() {
        logger.debug("Trim button tap - starting download process")
        logger.debug("Current video URL: \(String(describing: viewModel.currentVideoURL))")
        logger.debug("Current video time: \(String(describing: viewModel.currentVideoTime))")
        logger.debug("Current video duration: \(String(describing: viewModel.currentVideoDuration))")
        
        // Pause playback
        viewModel.pausePlayback()
        
        // Start the trim workflow with the download step
        trimStep = .downloading
    }
    
    private func downloadVideo() {
        guard let identifier = identifier else {
            saveError = "Video information not available"
            return
        }
        
        isDownloading = true
        downloadProgress = 0
        
        downloadService.downloadVideo(
            identifier: identifier,
            progressHandler: { progress in
                self.downloadProgress = progress
            },
            completionHandler: { result in
                self.isDownloading = false
                
                switch result {
                case .success:
                    self.showSaveSuccessAlert = true
                case .failure(let error):
                    self.saveError = "Failed to save video: \(error.localizedDescription)"
                }
            }
        )
    }
}

#Preview {
    VideoInfoOverlay(
        title: "Sample Video Title",
        collection: "avgeeks",
        description: "This is a sample description for the video that might span multiple lines when displayed in the app.",
        identifier: "sample_id",
        viewModel: VideoPlayerViewModel()
    )
    .background(Color.black)
}