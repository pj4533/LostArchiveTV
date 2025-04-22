import Foundation
import AVFoundation
import Photos
import OSLog
import UIKit

class VideoTrimManager {
    private let logger = Logger(subsystem: "com.sourcetable.LostArchiveTV", category: "trimming")
    
    func trimVideo(url: URL, startTime: CMTime, endTime: CMTime, completion: @escaping (Result<URL, Error>) -> Void) {
        let asset = AVAsset(url: url)
        
        // Create a new filename for the trimmed video
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        let outputURL = documentsDirectory.appendingPathComponent("trimmed_\(dateString).mp4")
        
        // Remove any existing file at the output URL
        try? FileManager.default.removeItem(at: outputURL)
        
        // Set up the export session
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            logger.error("Failed to create export session")
            completion(.failure(NSError(domain: "VideoTrimManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])))
            return
        }
        
        // Configure the export session
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        
        // Calculate the duration between start and end times
        let duration = CMTimeSubtract(endTime, startTime)
        exportSession.timeRange = CMTimeRange(start: startTime, duration: duration)
        
        // Log trim information for debugging
        self.logger.info("Starting trim: start=\(startTime.seconds)s, end=\(endTime.seconds)s, duration=\(duration.seconds)s")
        
        // Export the trimmed video
        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                switch exportSession.status {
                case .completed:
                    self.logger.info("Video trim completed: \(outputURL)")
                    
                    // Save to photo library after successful export
                    PHPhotoLibrary.requestAuthorization { status in
                        if status == .authorized {
                            PHPhotoLibrary.shared().performChanges {
                                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
                            } completionHandler: { success, error in
                                if success {
                                    self.logger.info("Trimmed video saved to Photos")
                                } else if let error = error {
                                    self.logger.error("Failed to save to Photos: \(error.localizedDescription)")
                                }
                            }
                        } else {
                            self.logger.warning("Photo library access not authorized")
                        }
                    }
                    
                    completion(.success(outputURL))
                    
                case .failed:
                    let error = exportSession.error ?? NSError(domain: "VideoTrimManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Export failed with unknown error"])
                    self.logger.error("Video trim failed: \(error.localizedDescription)")
                    completion(.failure(error))
                case .cancelled:
                    self.logger.error("Video trim cancelled. Error: \(exportSession.error?.localizedDescription ?? "No error details")")
                    completion(.failure(NSError(domain: "VideoTrimManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Export cancelled"])))
                default:
                    self.logger.warning("Unexpected export status: \(exportSession.status.rawValue)")
                    completion(.failure(NSError(domain: "VideoTrimManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Export ended with unexpected status"])))
                }
            }
        }
    }
    
    // Generate thumbnails for trim interface
    func generateThumbnails(from asset: AVAsset, count: Int = 10, completion: @escaping ([UIImage]) -> Void) {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 100, height: 100)
        
        // Get the duration of the video
        asset.loadValuesAsynchronously(forKeys: ["duration"]) {
            var error: NSError? = nil
            let status = asset.statusOfValue(forKey: "duration", error: &error)
            
            guard status == .loaded else {
                self.logger.error("Failed to load duration: \(error?.localizedDescription ?? "Unknown error")")
                completion([])
                return
            }
            
            let duration = asset.duration
            let durationSeconds = CMTimeGetSeconds(duration)
            
            guard durationSeconds > 0 else {
                self.logger.error("Invalid duration")
                completion([])
                return
            }
            
            var thumbnails: [UIImage] = []
            let group = DispatchGroup()
            
            // Generate thumbnails evenly spaced throughout the video
            for i in 0..<count {
                group.enter()
                
                let timeValue = durationSeconds * Double(i) / Double(count)
                let time = CMTime(seconds: timeValue, preferredTimescale: 600)
                
                generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cgImage, _, result, error in
                    defer { group.leave() }
                    
                    if let error = error {
                        self.logger.error("Thumbnail generation error: \(error.localizedDescription)")
                        return
                    }
                    
                    if let cgImage = cgImage, result == .succeeded {
                        let thumbnail = UIImage(cgImage: cgImage)
                        thumbnails.append(thumbnail)
                    }
                }
            }
            
            group.notify(queue: .main) {
                completion(thumbnails.sorted { lhs, rhs in
                    let lhsIndex = thumbnails.firstIndex(of: lhs) ?? 0
                    let rhsIndex = thumbnails.firstIndex(of: rhs) ?? 0
                    return lhsIndex < rhsIndex
                })
            }
        }
    }
    
    // Save video to Photos
    func saveToPhotoLibrary(videoURL: URL, completion: @escaping (Bool, Error?) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
                } completionHandler: { success, error in
                    completion(success, error)
                }
            } else {
                let error = NSError(domain: "VideoTrimManager", code: 5, userInfo: [NSLocalizedDescriptionKey: "Permission to access Photos not granted"])
                completion(false, error)
            }
        }
    }
}