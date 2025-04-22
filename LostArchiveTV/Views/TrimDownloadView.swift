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
                            .font(.system(size: 30))
                            .foregroundColor(.red)
                    } else {
                        // Download icon
                        Image(systemName: "arrow.down")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 70, height: 70)
                
                // Status text
                if let errorMessage = error {
                    Text("Download Failed")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal)
                } else {
                    Text("Downloading video")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                // Cancel button - smaller and less prominent
                Button(action: {
                    // Dismiss view and return to main player
                    onDownloadComplete(nil)
                }) {
                    Text("Cancel")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(8)
                }
                .padding(.top, 8)
            }
            .padding(24)
            .background(Color.black.opacity(0.7))
            .cornerRadius(16)
            .shadow(radius: 10)
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
                    
                    // Use VideoSaveManager to download with progress tracking
                    let downloadTask = URLSession.shared.downloadTask(with: videoURL) { tempFileURL, response, error in
                        // Handle download errors
                        if let error = error {
                            logger.error("Download failed: \(error.localizedDescription)")
                            Task { @MainActor in
                                self.isDownloading = false
                                self.error = error.localizedDescription
                            }
                            return
                        }
                        
                        guard let tempFileURL = tempFileURL else {
                            logger.error("Download completed but file URL is nil")
                            Task { @MainActor in
                                self.isDownloading = false
                                self.error = "Download failed with no file created"
                            }
                            return
                        }
                        
                        // Check response
                        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                            Task { @MainActor in
                                self.isDownloading = false
                                self.error = "Download failed with HTTP status: \(httpResponse.statusCode)"
                            }
                            return
                        }
                        
                        // Move the downloaded file to our destination
                        do {
                            try FileManager.default.moveItem(at: tempFileURL, to: tempURL)
                            
                            // Verify the file exists and has content
                            let attributes = try FileManager.default.attributesOfItem(atPath: tempURL.path)
                            let fileSize = attributes[.size] as? UInt64 ?? 0
                            self.logger.info("Download complete. File size: \(fileSize) bytes")
                            
                            if fileSize == 0 {
                                Task { @MainActor in
                                    self.isDownloading = false
                                    self.error = "Downloaded file is empty"
                                }
                                return
                            }
                            
                            // Success - complete the download flow
                            Task { @MainActor in
                                self.onDownloadComplete(tempURL)
                            }
                        } catch {
                            logger.error("Failed to process downloaded file: \(error.localizedDescription)")
                            Task { @MainActor in
                                self.isDownloading = false
                                self.error = error.localizedDescription
                            }
                        }
                    }
                    
                    // Set up progress tracking
                    downloadTask.resume()
                    
                    // Track download progress using an observation
                    let observation = downloadTask.progress.observe(\.fractionCompleted) { progress, _ in
                        Task { @MainActor in
                            self.downloadProgress = Float(progress.fractionCompleted)
                        }
                    }
                    
                    // Store the observation reference to keep it alive
                    objc_setAssociatedObject(downloadTask, "progressObservation", observation, .OBJC_ASSOCIATION_RETAIN)
                    
                } catch {
                    // Download setup failed
                    logger.error("Download setup failed: \(error.localizedDescription)")
                    self.isDownloading = false
                    self.error = error.localizedDescription 
                }
            }
        }
    }
}

#Preview {
    TrimDownloadView(viewModel: VideoPlayerViewModel()) { _ in }
}