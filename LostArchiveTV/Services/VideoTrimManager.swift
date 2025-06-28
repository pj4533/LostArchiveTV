import Foundation
import AVFoundation
import Photos
import OSLog
import UIKit

class VideoTrimManager {
    private let logger = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "trimming")
    
    func trimVideo(url: URL, startTime: CMTime, endTime: CMTime, completion: @escaping (Result<URL, Error>) -> Void) {
        self.logger.info("Starting trim process with URL: \(url.absoluteString)")
        
        // Validate the source file exists
        if !FileManager.default.fileExists(atPath: url.path) {
            self.logger.error("Source file does not exist: \(url.path)")
            completion(.failure(NSError(domain: "VideoTrimManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Source video file not found"])))
            return
        }
        
        // Create a unique output URL in documents directory
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        let outputURL = documentsDirectory.appendingPathComponent("trimmed_\(dateString).mp4")
        
        // Clean up any existing file
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        
        // Create the asset
        let asset = AVURLAsset(url: url)
        
        // Launch async task to perform the trim
        Task {
            do {
                try await self.performTrim(asset: asset, startTime: startTime, endTime: endTime, outputURL: outputURL)
                
                // Success - save to Photos library
                let success = try await self.saveToPhotosLibrary(videoURL: outputURL)
                if success {
                    self.logger.info("Video saved to Photos library")
                } else {
                    self.logger.warning("Video wasn't saved to Photos library")
                }
                
                // Return success to caller
                DispatchQueue.main.async {
                    completion(.success(outputURL))
                }
                
            } catch {
                self.logger.error("Trim failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // Modern async/await implementation of video trimming
    private func performTrim(asset: AVAsset, startTime: CMTime, endTime: CMTime, outputURL: URL) async throws {
        // Validate the asset properties
        do {
            // Load duration
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)
            
            self.logger.info("Asset loaded successfully. Duration: \(durationSeconds) seconds")
            
            // Validate time range
            if CMTimeCompare(startTime, duration) >= 0 || CMTimeCompare(endTime, duration) > 0 {
                let error = NSError(domain: "VideoTrimManager", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid time range for trimming"
                ])
                throw error
            }
            
            // Calculate trim range duration
            let rangeDuration = CMTimeSubtract(endTime, startTime)
            if CMTimeGetSeconds(rangeDuration) <= 0 {
                throw NSError(domain: "VideoTrimManager", code: 3, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid trim duration (must be positive)"
                ])
            }
            
            // Create export session
            guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
                throw NSError(domain: "VideoTrimManager", code: 4, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to create export session"
                ])
            }
            
            // Configure export
            exportSession.outputURL = outputURL
            exportSession.outputFileType = .mp4
            exportSession.timeRange = CMTimeRange(start: startTime, duration: rangeDuration)
            
            // Log detailed export information
            self.logger.info("Starting export: start=\(startTime.seconds)s, end=\(endTime.seconds)s, duration=\(rangeDuration.seconds)s")
            
            // Export and wait for completion using the new API
            if #available(iOS 18.0, *) {
                // Use the new export API for iOS 18+
                try await exportSession.export(to: outputURL, as: .mp4)
                
                // If we get here, export succeeded
                if FileManager.default.fileExists(atPath: outputURL.path) {
                    // Get file size for logging
                    let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
                    let fileSize = attributes[.size] as? UInt64 ?? 0
                    self.logger.info("Export completed successfully. File size: \(fileSize) bytes")
                    return
                } else {
                    throw NSError(domain: "VideoTrimManager", code: 5, userInfo: [
                        NSLocalizedDescriptionKey: "Export completed but file not found"
                    ])
                }
            } else {
                // Fallback to the old API for iOS 17 and earlier
                await exportSession.export()
                
                // Check status using the old API
                switch exportSession.status {
                case .completed:
                    if FileManager.default.fileExists(atPath: outputURL.path) {
                        // Get file size for logging
                        let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
                        let fileSize = attributes[.size] as? UInt64 ?? 0
                        self.logger.info("Export completed successfully. File size: \(fileSize) bytes")
                        return
                    } else {
                        throw NSError(domain: "VideoTrimManager", code: 5, userInfo: [
                            NSLocalizedDescriptionKey: "Export completed but file not found"
                        ])
                    }
                case .cancelled:
                    throw NSError(domain: "VideoTrimManager", code: 6, userInfo: [
                        NSLocalizedDescriptionKey: "Export cancelled"
                    ])
                case .failed:
                    if let error = exportSession.error {
                        throw error
                    } else {
                        throw NSError(domain: "VideoTrimManager", code: 7, userInfo: [
                            NSLocalizedDescriptionKey: "Export failed with unknown error"
                        ])
                    }
                default:
                    throw NSError(domain: "VideoTrimManager", code: 8, userInfo: [
                        NSLocalizedDescriptionKey: "Export ended with unexpected status"
                    ])
                }
            }
        } catch {
            self.logger.error("Trim operation failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Helper method to save video to Photos library using Swift Concurrency
    private func saveToPhotosLibrary(videoURL: URL) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.requestAuthorization { status in
                if status == .authorized {
                    PHPhotoLibrary.shared().performChanges {
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
                    } completionHandler: { success, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: success)
                        }
                    }
                } else {
                    let error = NSError(domain: "VideoTrimManager", code: 9, userInfo: [
                        NSLocalizedDescriptionKey: "Permission to access Photos not granted"
                    ])
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // Generate thumbnails for trim interface (completion handler version for backward compatibility)
    func generateThumbnails(from asset: AVAsset, count: Int = 10, completion: @escaping ([UIImage]) -> Void) {
        // Delegate to our async version and handle the completion
        Task {
            do {
                let thumbnails = try await generateThumbnailsAsync(from: asset, count: count)
                await MainActor.run {
                    completion(thumbnails)
                }
            } catch {
                self.logger.error("trim: failed to generate thumbnails: \(error.localizedDescription)")
                await MainActor.run {
                    completion([])
                }
            }
        }
    }

    // Modern async/await version of thumbnail generator
    func generateThumbnailsAsync(from asset: AVAsset, count: Int = 10) async throws -> [UIImage] {
        // Create image generator with optimized settings
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 100, height: 100)  // Small thumbnails for efficiency
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        self.logger.debug("trim: starting async thumbnail generation with count=\(count)")

        // Load video tracks to verify asset has visual content
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard !videoTracks.isEmpty else {
            self.logger.error("trim: asset contains no video tracks")
            throw NSError(domain: "VideoTrimManager", code: 10, userInfo: [
                NSLocalizedDescriptionKey: "No video tracks found in asset"
            ])
        }

        // Load duration
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)

        self.logger.debug("trim: generating thumbnails for \(durationSeconds)s video")

        guard durationSeconds > 0 else {
            self.logger.error("trim: invalid duration for thumbnail generation")
            throw NSError(domain: "VideoTrimManager", code: 11, userInfo: [
                NSLocalizedDescriptionKey: "Invalid video duration"
            ])
        }

        var thumbnails: [UIImage] = []

        // Get at least 2 thumbnails, cap at a reasonable number
        let safeCount = min(max(2, count), 30)

        // Generate thumbnails sequentially to avoid resource issues
        for i in 0..<safeCount {
            // Check if task has been cancelled
            try Task.checkCancellation()

            // Calculate time for this thumbnail
            let progress = Double(i) / Double(safeCount - 1)
            let timeValue = durationSeconds * progress
            let time = CMTime(seconds: timeValue, preferredTimescale: 600)

            do {
                // Generate thumbnail
                let imageResult = try await generator.image(at: time)
                let cgImage = imageResult.image
                let thumbnail = UIImage(cgImage: cgImage)
                thumbnails.append(thumbnail)

                // Log progress periodically
                if i == 0 || i == safeCount - 1 || i % 5 == 0 {
                    self.logger.debug("trim: generated thumbnail \(i+1)/\(safeCount)")
                }
            } catch {
                // Continue with other thumbnails if one fails
                self.logger.error("trim: failed to generate thumbnail \(i+1): \(error.localizedDescription)")
            }

            // Add small delay every few thumbnails to avoid overwhelming the system
            if i % 3 == 0 && i > 0 {
                try? await Task.sleep(for: .milliseconds(10))
            }
        }

        self.logger.debug("trim: completed generation of \(thumbnails.count) thumbnails")

        // If we couldn't generate any thumbnails, that's an error
        if thumbnails.isEmpty {
            throw NSError(domain: "VideoTrimManager", code: 12, userInfo: [
                NSLocalizedDescriptionKey: "Failed to generate any thumbnails"
            ])
        }

        return thumbnails
    }
}