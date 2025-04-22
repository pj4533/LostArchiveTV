import Foundation
import Photos
import OSLog

/// Service for handling video downloads from Internet Archive
class VideoDownloadService {
    private let logger = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "download")
    
    /// Download a video file for a given identifier
    /// - Parameters:
    ///   - identifier: Archive.org identifier
    ///   - progressHandler: Callback for progress updates
    ///   - completionHandler: Callback with the result (success or failure)
    func downloadVideo(
        identifier: String,
        progressHandler: @escaping (Float) -> Void,
        completionHandler: @escaping (Result<Void, Error>) -> Void
    ) {
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
                                completionHandler(.failure(NSError(domain: "VideoDownload", code: 1, userInfo: [
                                    NSLocalizedDescriptionKey: "No downloadable video file found"
                                ])))
                            }
                            return
                        }
                        
                        // Get the video URL
                        guard let videoURL = await archiveService.getFileDownloadURL(for: mp4File, identifier: identifier) else {
                            DispatchQueue.main.async {
                                completionHandler(.failure(NSError(domain: "VideoDownload", code: 2, userInfo: [
                                    NSLocalizedDescriptionKey: "Could not create download URL"
                                ])))
                            }
                            return
                        }
                        
                        // Use the VideoSaveManager to download and save the video
                        VideoSaveManager.shared.saveVideo(from: videoURL) { progress in
                            progressHandler(progress)
                        } completionHandler: { result in
                            DispatchQueue.main.async {
                                completionHandler(result)
                            }
                        }
                    } catch {
                        DispatchQueue.main.async {
                            completionHandler(.failure(error))
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completionHandler(.failure(NSError(domain: "VideoDownload", code: 3, userInfo: [
                        NSLocalizedDescriptionKey: "Permission to save photos is required. Please enable it in Settings."
                    ])))
                }
            }
        }
    }
}