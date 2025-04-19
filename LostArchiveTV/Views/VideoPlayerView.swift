import SwiftUI
import AVKit
import OSLog

struct VideoPlayerView: View {
    let video: ArchiveVideo
    @State private var videoDetails: ArchiveVideoDetails?
    @State private var isLoading = true
    @State private var error: String?
    
    var body: some View {
        ZStack {
            if isLoading {
                ProgressView("Loading...")
            } else if let error = error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .padding()
                    Text("Error loading video")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            } else if let videoURL = videoDetails?.videoURL() {
                let player = AVPlayer(url: videoURL)
                VideoPlayer(player: player)
                    .edgesIgnoringSafeArea(.all)
                    .onAppear {
                        Logger.videoPlayback.info("Starting video playback: \(video.title)")
                        player.play()
                    }
            } else {
                Text("Could not find video file")
            }
        }
        .navigationTitle(video.title)
        .task {
            await loadVideoDetails()
        }
    }
    
    private func loadVideoDetails() async {
        Logger.videoPlayback.debug("Loading video details for: \(video.identifier)")
        isLoading = true
        error = nil
        
        do {
            videoDetails = try await ArchiveService.shared.getVideoDetails(identifier: video.identifier)
            
            if let videoURL = videoDetails?.videoURL() {
                Logger.videoPlayback.info("Successfully loaded video: \(video.title), URL: \(videoURL)")
            } else {
                Logger.videoPlayback.error("No video file found for: \(video.title)")
            }
            
            isLoading = false
        } catch {
            Logger.videoPlayback.error("Failed to load video details: \(error.localizedDescription)")
            self.error = error.localizedDescription
            isLoading = false
        }
    }
}