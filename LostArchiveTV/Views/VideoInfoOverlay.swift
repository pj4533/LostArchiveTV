//
//  VideoInfoOverlay.swift
//  LostArchiveTV
//
//  Created by Claude on 4/19/25.
//

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
    @Environment(\.openURL) private var openURL
    
    // Logger for debugging
    private let logger = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "ui")
    
    // Reference to the view model - passed from parent
    @ObservedObject var viewModel: VideoPlayerViewModel
    
    var body: some View {
        ZStack {
            VStack {
                Spacer()
                
                // Bottom overlay with title and description
                VStack(alignment: .leading, spacing: 8) {
                    // Video title and description
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title ?? identifier ?? "Unknown Title")
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        if let collection = collection {
                            Text("Collection: \(collection)")
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(1)
                        }
                        
                        Text(description ?? "Internet Archive random video clip")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 15)
                    .padding(.trailing, 60) // Make room for the buttons on the right
                    
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
            
            // Buttons stack at right side (aligned to trailing edge)
            HStack {
                Spacer() // This pushes the VStack to the right edge
                
                VStack(spacing: 12) {
                    Spacer()
                    // Add more space for potential future buttons
                    
                    // Trim button - now starts the download flow first
                    Button(action: {
                        logger.debug("Trim button tap - starting download process")
                        logger.debug("Current video URL: \(String(describing: viewModel.currentVideoURL))")
                        logger.debug("Current video time: \(String(describing: viewModel.currentVideoTime))")
                        logger.debug("Current video duration: \(String(describing: viewModel.currentVideoDuration))")
                        
                        // Pause playback and start download flow
                        viewModel.pausePlayback()
                        showTrimDownloadView = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.1))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "timeline.selection")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 22, height: 22)
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                        }
                    }
                    .disabled(viewModel.currentVideoURL == nil)
                    
                    // Download button
                    Button(action: {
                        if !isDownloading {
                            downloadVideo()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.1))
                                .frame(width: 44, height: 44)
                            
                            if isDownloading {
                                Circle()
                                    .trim(from: 0, to: CGFloat(downloadProgress))
                                    .stroke(Color.white, lineWidth: 2)
                                    .frame(width: 40, height: 40)
                                    .rotationEffect(.degrees(-90))
                            } else {
                                Image(systemName: "square.and.arrow.down.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 22, height: 22)
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                            }
                        }
                    }
                    .disabled(isDownloading)
                    
                    // Thumbnail button to open in Archive.org
                    Button(action: {
                        if let identifier = identifier {
                            if let url = URL(string: "https://archive.org/details/\(identifier)") {
                                openURL(url)
                            }
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.1))
                                .frame(width: 44, height: 44)
                            
                            Image("internetarchive")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                        }
                    }
                    
                    // No extra bottom padding needed - will align with text at bottom
                }
                .padding(.trailing, 8)
            }
        }
        // Show download progress view first
        .sheet(isPresented: $showTrimDownloadView, onDismiss: {
            // If we got a downloaded URL, show the trim view
            if let downloadedURL = downloadedVideoURL {
                showTrimView = true
            } else {
                // If download failed, resume playback
                logger.debug("Download sheet dismissed without URL, resuming main playback")
                viewModel.resumePlayback()
            }
        }) {
            TrimDownloadView(viewModel: viewModel) { downloadedURL in
                self.downloadedVideoURL = downloadedURL
                self.showTrimDownloadView = false
            }
        }
        
        // Show trim view after download completes
        .sheet(isPresented: $showTrimView, onDismiss: {
            // Only resume playback - the cleanup is handled explicitly before dismissal
            logger.debug("Trim sheet dismissed, resuming main playback")
            // Reset the downloaded URL
            downloadedVideoURL = nil
            viewModel.resumePlayback()
        }) {
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
    
    private func downloadVideo() {
        guard let identifier = identifier else {
            saveError = "Video information not available"
            return
        }
        
        isDownloading = true
        downloadProgress = 0
        
        // Check photo library permission
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                // Get the current video URL from the VideoPlayerViewModel
                Task {
                    do {
                        // Fetch the video URL - using the Archive Service
                        let archiveService = ArchiveService()
                        let metadata = try await archiveService.fetchMetadata(for: identifier)
                        
                        let playableFiles = await archiveService.findPlayableFiles(in: metadata)
                        guard let mp4File = playableFiles.first else {
                            DispatchQueue.main.async {
                                self.isDownloading = false
                                self.saveError = "No downloadable video file found"
                            }
                            return
                        }
                        
                        // Get the video URL
                        guard let videoURL = await archiveService.getFileDownloadURL(for: mp4File, identifier: identifier) else {
                            DispatchQueue.main.async {
                                self.isDownloading = false
                                self.saveError = "Could not create download URL"
                            }
                            return
                        }
                        
                        // Use the VideoSaveManager to download and save the video
                        VideoSaveManager.shared.saveVideo(from: videoURL) { progress in
                            self.downloadProgress = progress
                        } completionHandler: { result in
                            DispatchQueue.main.async {
                                self.isDownloading = false
                                
                                switch result {
                                case .success:
                                    self.showSaveSuccessAlert = true
                                case .failure(let error):
                                    self.saveError = "Failed to save video: \(error.localizedDescription)"
                                }
                            }
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.isDownloading = false
                            self.saveError = "Error preparing video for download: \(error.localizedDescription)"
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.saveError = "Permission to save photos is required. Please enable it in Settings."
                    self.isDownloading = false
                }
            }
        }
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
