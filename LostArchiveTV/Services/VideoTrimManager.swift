import Foundation
import AVFoundation
import Photos
import OSLog
import UIKit

class VideoTrimManager {
    private let logger = Logger(subsystem: "com.sourcetable.LostArchiveTV", category: "trimming")
    
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
        let asset = AVAsset(url: url)
        
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
            
            // Export and wait for completion
            try await exportSession.export()
            
            // Validate export was successful
            if exportSession.status == .completed {
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
            } else if exportSession.status == .cancelled {
                throw NSError(domain: "VideoTrimManager", code: 6, userInfo: [
                    NSLocalizedDescriptionKey: "Export cancelled"
                ])
            } else if exportSession.status == .failed {
                if let error = exportSession.error {
                    throw error
                } else {
                    throw NSError(domain: "VideoTrimManager", code: 7, userInfo: [
                        NSLocalizedDescriptionKey: "Export failed with unknown error"
                    ])
                }
            } else {
                throw NSError(domain: "VideoTrimManager", code: 8, userInfo: [
                    NSLocalizedDescriptionKey: "Export ended with unexpected status: \(exportSession.status.rawValue)"
                ])
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
    
    // Legacy method for compatibility
    func saveToPhotoLibrary(videoURL: URL, completion: @escaping (Bool, Error?) -> Void) {
        Task {
            do {
                let success = try await saveToPhotosLibrary(videoURL: videoURL)
                completion(success, nil)
            } catch {
                completion(false, error)
            }
        }
    }
    
    // Generate thumbnails for trim interface
    func generateThumbnails(from asset: AVAsset, count: Int = 10, completion: @escaping ([UIImage]) -> Void) {
        // Create image generator with better settings
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 100, height: 100)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        
        // Use Swift Concurrency
        Task {
            do {
                // Load duration modern way
                let duration = try await asset.load(.duration)
                let durationSeconds = CMTimeGetSeconds(duration)
                
                self.logger.debug("Generating \(count) thumbnails for video with duration \(durationSeconds) seconds")
                
                guard durationSeconds > 0 else {
                    self.logger.error("Invalid duration for thumbnail generation")
                    await MainActor.run {
                        completion([])
                    }
                    return
                }
                
                var thumbnails: [UIImage] = []
                
                // Generate thumbnails in parallel
                for i in 0..<count {
                    // Calculate time for this thumbnail
                    let timeValue = durationSeconds * Double(i) / Double(count)
                    let time = CMTime(seconds: timeValue, preferredTimescale: 600)
                    
                    do {
                        // Generate thumbnail using modern API
                        let cgImage = try await generator.image(at: time).image
                        let thumbnail = UIImage(cgImage: cgImage)
                        thumbnails.append(thumbnail)
                    } catch {
                        self.logger.error("Failed to generate thumbnail at time \(timeValue): \(error.localizedDescription)")
                    }
                }
                
                // Return thumbnails on main thread
                await MainActor.run {
                    self.logger.debug("Generated \(thumbnails.count) thumbnails")
                    completion(thumbnails)
                }
                
            } catch {
                self.logger.error("Failed to load asset duration: \(error.localizedDescription)")
                await MainActor.run {
                    completion([])
                }
            }
        }
    }
}