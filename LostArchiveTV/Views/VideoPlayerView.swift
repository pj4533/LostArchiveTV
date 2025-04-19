import SwiftUI
import AVKit

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
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .edgesIgnoringSafeArea(.all)
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
        isLoading = true
        error = nil
        
        do {
            videoDetails = try await ArchiveService.shared.getVideoDetails(identifier: video.identifier)
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }
}