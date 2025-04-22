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
    @State private var showTrimView = false
    @State private var showTrimDownloadView = false
    @State private var downloadedVideoURL: URL? = nil
    
    // Logger for debugging
    private let logger = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "ui")
    
    // Services
    private let downloadService = VideoDownloadService()
    
    // Reference to the view model - passed from parent
    @ObservedObject var viewModel: VideoPlayerViewModel
    
    var body: some View {
        ZStack {
            // Bottom info panel with gradient background
            bottomInfoPanel
            
            // Right-side buttons
            buttonPanel
        }
        // Sheets and alerts
        .sheet(isPresented: $showTrimDownloadView, onDismiss: handleTrimDownloadDismissal) {
            TrimDownloadView(viewModel: viewModel) { downloadedURL in
                self.downloadedVideoURL = downloadedURL
                self.showTrimDownloadView = false
            }
        }
        .sheet(isPresented: $showTrimView, onDismiss: handleTrimViewDismissal) {
            if let downloadedURL = downloadedVideoURL,
               let currentTime = viewModel.currentVideoTime,
               let duration = viewModel.currentVideoDuration {
                // Use the downloaded file URL
                VideoTrimView(viewModel: VideoTrimViewModel(
                    assetURL: downloadedURL,
                    currentPlaybackTime: currentTime,
                    duration: duration
                ))
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
                    identifier: identifier
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
        
        // Pause playback and start download flow
        viewModel.pausePlayback()
        showTrimDownloadView = true
    }
    
    private func handleTrimDownloadDismissal() {
        // If we got a downloaded URL, show the trim view
        if let downloadedURL = downloadedVideoURL {
            showTrimView = true
        } else {
            // If download failed, resume playback
            logger.debug("Download sheet dismissed without URL, resuming main playback")
            viewModel.resumePlayback()
        }
    }
    
    private func handleTrimViewDismissal() {
        // Only resume playback - the cleanup is handled explicitly before dismissal
        logger.debug("Trim sheet dismissed, resuming main playback")
        // Reset the downloaded URL
        downloadedVideoURL = nil
        viewModel.resumePlayback()
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