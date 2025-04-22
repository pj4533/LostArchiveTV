import Foundation
import AVFoundation
import OSLog

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
        exportSession.timeRange = CMTimeRange(start: startTime, end: endTime)
        
        // Export the trimmed video
        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                switch exportSession.status {
                case .completed:
                    self.logger.info("Video trim completed: \(outputURL)")
                    completion(.success(outputURL))
                case .failed:
                    let error = exportSession.error ?? NSError(domain: "VideoTrimManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Export failed with unknown error"])
                    self.logger.error("Video trim failed: \(error.localizedDescription)")
                    completion(.failure(error))
                case .cancelled:
                    self.logger.info("Video trim cancelled")
                    completion(.failure(NSError(domain: "VideoTrimManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Export cancelled"])))
                default:
                    self.logger.warning("Unexpected export status: \(exportSession.status.rawValue)")
                    completion(.failure(NSError(domain: "VideoTrimManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Export ended with unexpected status"])))
                }
            }
        }
    }
}