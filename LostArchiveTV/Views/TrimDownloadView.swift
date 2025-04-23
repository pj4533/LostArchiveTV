import SwiftUI
import OSLog
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
    private let logger = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "trimming")
    
    // Service for handling downloads
    private let downloadService = VideoDownloadService()
    
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
                    Text("Preparing for trim...")
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
            downloadVideoForTrimming()
        }
    }
    
    private func downloadVideoForTrimming() {
        Task {
            guard let identifier = currentIdentifier else {
                self.error = "No video selected for trimming"
                self.isDownloading = false
                return
            }
            
            // Create temporary file location for trim operation
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("trim_\(UUID().uuidString)")
                .appendingPathExtension("mp4")
            
            logger.debug("Starting download for trimming: \(identifier) to \(tempURL.path)")
            
            // Use custom download method for trim operation
            do {
                try await downloadVideoToFile(identifier: identifier, destinationURL: tempURL)
                
                // Success - return the downloaded file URL
                self.onDownloadComplete(tempURL)
            } catch {
                logger.error("Video download for trimming failed: \(error.localizedDescription)")
                self.error = error.localizedDescription
                self.isDownloading = false
            }
        }
    }
    
    // Custom download method that uses our service but saves to a specific location
    private func downloadVideoToFile(identifier: String, destinationURL: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            // Create service instances
            let archiveService = ArchiveService()
            
            // Start the process
            Task {
                do {
                    // Get metadata
                    let metadata = try await archiveService.fetchMetadata(for: identifier)
                    
                    // Find MP4 file
                    let playableFiles = await archiveService.findPlayableFiles(in: metadata)
                    
                    guard let mp4File = playableFiles.first,
                          let videoURL = await archiveService.getFileDownloadURL(for: mp4File, identifier: identifier) else {
                        throw NSError(domain: "TrimDownload", code: 2, userInfo: [
                            NSLocalizedDescriptionKey: "Could not find playable file"
                        ])
                    }
                    
                    // Now download to our specific location
                    let downloadTask = URLSession.shared.downloadTask(with: videoURL) { tempFileURL, response, error in
                        // Handle download errors
                        if let error = error {
                            continuation.resume(throwing: error)
                            return
                        }
                        
                        guard let tempFileURL = tempFileURL else {
                            continuation.resume(throwing: NSError(domain: "TrimDownload", code: 3, userInfo: [
                                NSLocalizedDescriptionKey: "Download failed with no file created"
                            ]))
                            return
                        }
                        
                        // Check response
                        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                            continuation.resume(throwing: NSError(domain: "TrimDownload", code: 4, userInfo: [
                                NSLocalizedDescriptionKey: "Download failed with HTTP status: \(httpResponse.statusCode)"
                            ]))
                            return
                        }
                        
                        // Move the downloaded file to our destination
                        do {
                            if FileManager.default.fileExists(atPath: destinationURL.path) {
                                try FileManager.default.removeItem(at: destinationURL)
                            }
                            try FileManager.default.moveItem(at: tempFileURL, to: destinationURL)
                            
                            // Verify the file exists and has content
                            let attributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
                            let fileSize = attributes[.size] as? UInt64 ?? 0
                            
                            if fileSize == 0 {
                                continuation.resume(throwing: NSError(domain: "TrimDownload", code: 5, userInfo: [
                                    NSLocalizedDescriptionKey: "Downloaded file is empty"
                                ]))
                                return
                            }
                            
                            // Success
                            continuation.resume(returning: ())
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                    
                    // Set up progress tracking
                    downloadTask.resume()
                    
                    // Track download progress
                    let observation = downloadTask.progress.observe(\.fractionCompleted) { progress, _ in
                        Task { @MainActor in
                            self.downloadProgress = Float(progress.fractionCompleted)
                        }
                    }
                    
                    // Store the observation reference to keep it alive
                    objc_setAssociatedObject(downloadTask, "progressObservation", observation, .OBJC_ASSOCIATION_RETAIN)
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

#Preview {
    TrimDownloadView(viewModel: VideoPlayerViewModel()) { _ in }
}
