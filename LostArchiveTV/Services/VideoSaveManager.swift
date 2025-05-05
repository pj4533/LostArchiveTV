//
//  VideoSaveManager.swift
//  LostArchiveTV
//
//  Created by Claude on 4/21/25.
//

import Foundation
import AVFoundation
import Photos
import OSLog

class VideoSaveManager {
    
    // Shared instance
    static let shared = VideoSaveManager()
    
    private init() {}
    
    /// Download and save a video to the photo library
    /// - Parameters:
    ///   - url: The URL of the video to download
    ///   - progressHandler: Closure that reports download progress from 0.0 to 1.0
    ///   - completionHandler: Closure called when download completes or fails
    func saveVideo(from url: URL, progressHandler: @escaping (Float) -> Void, completionHandler: @escaping (Result<Void, Error>) -> Void) {
        // Create a temporary directory to store the downloaded file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileName = UUID().uuidString + ".mp4"
        let localURL = tempDir.appendingPathComponent(tempFileName)
        
        // Download the video file with cookie header
        var request = URLRequest(url: url)
        let headers: [String: String] = [
            "Cookie": EnvironmentService.shared.archiveCookie
        ]
        request.allHTTPHeaderFields = headers
        
        let downloadTask = URLSession.shared.downloadTask(with: request) { tempFileURL, response, error in
            // Handle download errors
            if let error = error {
                Logger.videoPlayback.error("Failed to download video: \(error.localizedDescription)")
                completionHandler(.failure(error))
                return
            }
            
            guard let tempFileURL = tempFileURL else {
                Logger.videoPlayback.error("Download completed but file URL is nil")
                completionHandler(.failure(NSError(domain: "VideoSaveManager", code: 100, userInfo: [NSLocalizedDescriptionKey: "Download failed with no file created"])))
                return
            }
            
            // Move the downloaded file to our temp location
            do {
                if FileManager.default.fileExists(atPath: localURL.path) {
                    try FileManager.default.removeItem(at: localURL)
                }
                try FileManager.default.moveItem(at: tempFileURL, to: localURL)
                
                // Save the video to the photo library
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: localURL)
                } completionHandler: { success, error in
                    // Clean up the temporary file
                    try? FileManager.default.removeItem(at: localURL)
                    
                    if let error = error {
                        Logger.videoPlayback.error("Failed to save video to photo library: \(error.localizedDescription)")
                        completionHandler(.failure(error))
                        return
                    }
                    
                    if success {
                        Logger.videoPlayback.info("Successfully saved video to photo library")
                        completionHandler(.success(()))
                    } else {
                        Logger.videoPlayback.error("Failed to save video to photo library")
                        completionHandler(.failure(NSError(domain: "VideoSaveManager", code: 101, userInfo: [NSLocalizedDescriptionKey: "Failed to save video to photo library"])))
                    }
                }
            } catch {
                Logger.videoPlayback.error("Failed to process downloaded video: \(error.localizedDescription)")
                completionHandler(.failure(error))
            }
        }
        
        // Set up progress tracking
        downloadTask.resume()
        
        // Track download progress using an observation
        let observation = downloadTask.progress.observe(\.fractionCompleted) { progress, _ in
            DispatchQueue.main.async {
                progressHandler(Float(progress.fractionCompleted))
            }
        }
        
        // Store the observation reference in a dictionary to prevent it from being deallocated
        // This is a simple way to keep the observation alive until the download completes
        objc_setAssociatedObject(downloadTask, "progressObservation", observation, .OBJC_ASSOCIATION_RETAIN)
    }
}