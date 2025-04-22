import SwiftUI
import OSLog
import Photos
import AVFoundation

struct TrimDownloadView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    var onDownloadComplete: (URL?) -> Void
    
    @State private var isDownloading = true
    @State private var downloadProgress: Float = 0
    @State private var error: String? = nil
    @Environment(\.dismiss) private var dismiss
    
    // Get the current identifier directly from viewModel
    private var currentIdentifier: String? {
        return viewModel.currentIdentifier
    }
    
    // Logger for debugging
    private let logger = Logger(subsystem: "com.sourcetable.LostArchiveTV", category: "trimming")
    
    var body: some View {
        ZStack {
            // Background color
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                // Header
                Text("Preparing Video")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top, 40)
                
                Spacer()
                
                if isDownloading {
                    // Download progress UI
                    VStack(spacing: 30) {
                        Text("Downloading video for trimming...")
                            .foregroundColor(.white)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        Text("This may take a few moments depending on the video size")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(2.0)
                            .padding(.vertical, 40)
                    }
                    .padding(.horizontal, 30)
                } else if let errorMessage = error {
                    // Error message
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.red)
                            .padding(.bottom, 10)
                        
                        Text("Download Failed")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(errorMessage)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                    }
                    .padding(.horizontal, 30)
                    
                    Button(action: {
                        // Dismiss view and return to main player
                        onDownloadComplete(nil)
                    }) {
                        Text("Cancel")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: 250)
                            .background(Color.red.opacity(0.7))
                            .cornerRadius(10)
                    }
                    .padding(.top, 40)
                }
                
                Spacer()
                
                // Always show cancel button during download
                if isDownloading {
                    Button(action: {
                        // Dismiss view and return to main player
                        onDownloadComplete(nil)
                    }) {
                        Text("Cancel")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: 250)
                            .background(Color.red.opacity(0.7))
                            .cornerRadius(10)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            // Start downloading when view appears
            Task {
                isDownloading = true
                
                do {
                    // Manual download instead of using view model method
                    guard let identifier = currentIdentifier else {
                        throw NSError(domain: "TrimDownload", code: 1, userInfo: [
                            NSLocalizedDescriptionKey: "No video selected for trimming"
                        ])
                    }
                    
                    // Create service instances directly
                    let archiveService = ArchiveService()
                    
                    // Get metadata
                    let metadata = try await archiveService.fetchMetadata(for: identifier)
                    
                    // Find MP4 file
                    let mp4Files = await archiveService.findPlayableFiles(in: metadata)
                    
                    guard let mp4File = mp4Files.first,
                          let videoURL = await archiveService.getFileDownloadURL(for: mp4File, identifier: identifier) else {
                        throw NSError(domain: "TrimDownload", code: 2, userInfo: [
                            NSLocalizedDescriptionKey: "Could not find playable file"
                        ])
                    }
                    
                    // Create a unique temporary file path
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("trim_\(UUID().uuidString)")
                        .appendingPathExtension("mp4")
                    
                    logger.debug("Downloading video for trimming: \(videoURL)")
                    
                    // Use URLSession with async/await for download
                    let (downloadURL, response) = try await URLSession.shared.download(from: videoURL, delegate: nil)
                    
                    // Check response
                    if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                        throw NSError(domain: "TrimDownload", code: 3, userInfo: [
                            NSLocalizedDescriptionKey: "Download failed with HTTP status: \(httpResponse.statusCode)"
                        ])
                    }
                    
                    // Move the downloaded file to our destination
                    try FileManager.default.moveItem(at: downloadURL, to: tempURL)
                    
                    // Verify the file exists and has content
                    let attributes = try FileManager.default.attributesOfItem(atPath: tempURL.path)
                    let fileSize = attributes[.size] as? UInt64 ?? 0
                    logger.info("Download complete. File size: \(fileSize) bytes")
                    
                    if fileSize == 0 {
                        throw NSError(domain: "TrimDownload", code: 4, userInfo: [
                            NSLocalizedDescriptionKey: "Downloaded file is empty"
                        ])
                    }
                    
                    // Success - complete the download flow
                    onDownloadComplete(tempURL)
                    
                } catch {
                    // Download failed
                    logger.error("Download failed: \(error.localizedDescription)")
                    isDownloading = false
                    self.error = error.localizedDescription 
                }
            }
        }
    }
}

#Preview {
    TrimDownloadView(viewModel: VideoPlayerViewModel()) { _ in }
}