//
//  FavoritesPlayerView.swift
//  LostArchiveTV
//
//  Created by Claude on 4/24/25.
//

import SwiftUI
import AVKit
import OSLog

struct FavoritesPlayerView: View {
    @ObservedObject var viewModel: FavoritesViewModel
    @Binding var isPresented: Bool
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var isDownloading = false
    @State private var downloadProgress: Float = 0
    @State private var showTrimView = false
    @State private var showSaveSuccessAlert = false
    @State private var saveError: String? = nil
    @State private var downloadedVideoURL: URL? = nil
    @State private var trimStep: TrimWorkflowStep = .none
    
    private let dragThreshold: CGFloat = 100
    private let downloadService = VideoDownloadService()
    
    enum TrimWorkflowStep {
        case none        // No trim action in progress
        case downloading // Downloading video for trimming
        case trimming    // Showing trim interface
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if let video = viewModel.currentVideo {
                    // Video player content
                    ZStack {
                        if let player = viewModel.player {
                            VideoPlayer(player: player)
                                .aspectRatio(16/9, contentMode: .fit)
                                .edgesIgnoringSafeArea(.all)
                        }
                        
                        // Controls
                        VStack {
                            // Top controls
                            HStack {
                                // Back button
                                Button(action: {
                                    viewModel.pausePlayback()
                                    isPresented = false
                                }) {
                                    Image(systemName: "chevron.left")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .padding(12)
                                        .background(Circle().fill(Color.black.opacity(0.5)))
                                }
                                .padding(.top, 50)
                                .padding(.leading, 16)
                                
                                Spacer()
                                
                                // Right-side button panel
                                VStack(spacing: 12) {
                                    // Favorite button at the top
                                    OverlayButton(
                                        action: {
                                            viewModel.toggleFavorite()
                                            // Add haptic feedback
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        },
                                        disabled: viewModel.currentVideo == nil
                                    ) {
                                        Image(systemName: viewModel.isFavorite(video) ? "heart.fill" : "heart")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 22, height: 22)
                                            .foregroundColor(viewModel.isFavorite(video) ? .red : .white)
                                            .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                                    }
                                    
                                    Spacer()
                                    
                                    // Restart video button
                                    OverlayButton(
                                        action: {
                                            viewModel.restartVideo()
                                        },
                                        disabled: false
                                    ) {
                                        Image(systemName: "backward.end")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 16, height: 16)
                                            .foregroundColor(.white)
                                            .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                                    }
                                    
                                    // Trim button - starts download flow first
                                    OverlayButton(
                                        action: startTrimFlow,
                                        disabled: viewModel.currentVideo == nil
                                    ) {
                                        Image(systemName: "selection.pin.in.out")
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
                                    ArchiveButton(identifier: video.identifier)
                                }
                                .padding(.trailing, 16)
                                .padding(.top, 50)
                            }
                            
                            Spacer()
                            
                            // Bottom info panel
                            BottomInfoPanel(
                                title: video.title,
                                collection: video.collection,
                                description: video.description,
                                identifier: video.identifier,
                                currentTime: viewModel.player?.currentTime().seconds,
                                duration: viewModel.videoDuration
                            )
                        }
                    }
                    .offset(y: dragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if !isDragging {
                                    isDragging = true
                                }
                                dragOffset = value.translation.height
                            }
                            .onEnded { value in
                                isDragging = false
                                if dragOffset > dragThreshold {
                                    // Swipe down - previous video
                                    withAnimation {
                                        dragOffset = geometry.size.height
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        viewModel.goToPreviousVideo()
                                        dragOffset = 0
                                    }
                                } else if dragOffset < -dragThreshold {
                                    // Swipe up - next video
                                    withAnimation {
                                        dragOffset = -geometry.size.height
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        viewModel.goToNextVideo()
                                        dragOffset = 0
                                    }
                                } else {
                                    // Return to center
                                    withAnimation {
                                        dragOffset = 0
                                    }
                                }
                            }
                    )
                } else {
                    // No video selected or all favorites removed
                    VStack(spacing: 24) {
                        Image(systemName: "heart.slash")
                            .font(.system(size: 64))
                            .foregroundColor(.gray)
                        
                        Text("No Favorites")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Button("Return to Favorites") {
                            isPresented = false
                        }
                        .padding()
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                    }
                }
            }
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
                    if trimStep == .downloading, let video = viewModel.currentVideo {
                        // Download sheet
                        FavoritesTrimDownloadView(video: video) { downloadedURL in
                            if let url = downloadedURL {
                                // Success - move to trim step
                                Logger.caching.debug("Download successful, transitioning to trim step with URL: \(url.absoluteString)")
                                self.downloadedVideoURL = url
                                self.trimStep = .trimming
                            } else {
                                // Failed download - dismiss everything
                                Logger.caching.debug("Download failed or was cancelled, dismissing workflow")
                                self.downloadedVideoURL = nil
                                self.trimStep = .none
                            }
                        }
                    } else if trimStep == .trimming, 
                            let downloadedURL = downloadedVideoURL,
                            let player = viewModel.player {
                        // Trim view
                        VideoTrimView(viewModel: VideoTrimViewModel(
                            assetURL: downloadedURL,
                            currentPlaybackTime: player.currentTime(),
                            duration: player.currentItem?.duration ?? CMTime.zero
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
    }
    
    // MARK: - Actions
    
    private func startTrimFlow() {
        Logger.caching.debug("Trim button tap - starting download process")
        
        // Pause playback
        viewModel.pausePlayback()
        
        // Start the trim workflow with the download step
        trimStep = .downloading
    }
    
    private func downloadVideo() {
        guard let video = viewModel.currentVideo else {
            saveError = "Video information not available"
            return
        }
        
        isDownloading = true
        downloadProgress = 0
        
        downloadService.downloadVideo(
            identifier: video.identifier,
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

// Helper view to display TrimDownloadView for a CachedVideo
struct FavoritesTrimDownloadView: View {
    let video: CachedVideo
    let onComplete: (URL?) -> Void
    private let videoService = VideoDownloadService()
    
    @State private var isDownloading = true
    @State private var downloadProgress: Float = 0
    @State private var error: String? = nil
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        // Simple transparent modal overlay with progress indicator
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
            
            // Container with rounded corners
            VStack(spacing: 16) {
                // Download progress indicator
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 4)
                        .frame(width: 60, height: 60)
                    
                    if isDownloading {
                        Circle()
                            .trim(from: 0, to: CGFloat(downloadProgress))
                            .stroke(Color.white, lineWidth: 4)
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                    }
                    
                    // Show error icon if there's an error
                    if let _ = error {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.title)
                    } else {
                        Image(systemName: "arrow.down.circle")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }
                
                // Status text
                Text(error != nil ? "Download Failed" : "Downloading Video")
                    .font(.headline)
                    .foregroundColor(.white)
                
                // Error details or progress percentage
                if let errorText = error {
                    Text(errorText)
                        .font(.caption)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else {
                    Text("\(Int(downloadProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                
                // Actions
                HStack(spacing: 16) {
                    // Cancel button
                    Button("Cancel") {
                        onComplete(nil)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.gray.opacity(0.5))
                    .cornerRadius(8)
                    .foregroundColor(.white)
                    
                    // Retry button
                    if let _ = error {
                        Button("Retry") {
                            error = nil
                            isDownloading = true
                            downloadProgress = 0
                            startDownload()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.blue)
                        .cornerRadius(8)
                        .foregroundColor(.white)
                    }
                }
                .padding(.top, 8)
            }
            .padding(24)
            .background(Color.black.opacity(0.8))
            .cornerRadius(16)
            .shadow(radius: 10)
        }
        .onAppear {
            // Start download when view appears
            startDownload()
        }
    }
    
    // Start downloading the video file
    private func startDownload() {
        let identifier = video.identifier
        
        self.downloadProgress = 0
        self.isDownloading = true
        self.error = nil
        
        videoService.downloadVideoToTemp(
            identifier: identifier,
            progressHandler: { progress in
                self.downloadProgress = progress
            },
            completionHandler: { result in
                switch result {
                case .success(let url):
                    onComplete(url)
                case .failure(let error):
                    self.isDownloading = false
                    self.error = error.localizedDescription
                }
            }
        )
    }
}

struct VideoInfo {
    let identifier: String
    let title: String
    let description: String
    let year: String
    let runtime: String
    let collection: String?
    let url: URL?
    let thumbnailURL: URL?
}