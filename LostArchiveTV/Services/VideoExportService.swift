import Foundation
import AVFoundation
import Photos
import OSLog

/// Manages exporting trimmed videos and saving to the photo library
class VideoExportService {
    private let logger = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "export")
    private let trimManager = VideoTrimManager()
    
    /// Export and save a trimmed video
    /// - Parameters:
    ///   - localFileURL: The URL of the local video file to trim
    ///   - startTime: Start time for the trim
    ///   - endTime: End time for the trim
    /// - Returns: Boolean indicating success
    /// - Throws: Error if export fails
    func exportAndSaveVideo(
        localFileURL: URL,
        startTime: CMTime,
        endTime: CMTime
    ) async throws -> Bool {
        // Verify the file exists and has content
        if !FileManager.default.fileExists(atPath: localFileURL.path) {
            logger.error("Local file does not exist at path: \(localFileURL.path)")
            throw NSError(domain: "VideoExport", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Video file not found."
            ])
        }
        
        // Get file size for verification
        let attributes = try FileManager.default.attributesOfItem(atPath: localFileURL.path)
        let fileSize = attributes[.size] as? UInt64 ?? 0
        logger.info("Trimming local file: \(localFileURL.path), size: \(fileSize) bytes")
        
        if fileSize == 0 {
            throw NSError(domain: "VideoExport", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Downloaded file is empty. Please try again."
            ])
        }
        
        // Check for Photos permission
        let authStatus = try await checkPhotosPermission()
        
        if authStatus != .authorized {
            throw NSError(domain: "VideoExport", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Permission to save to Photos is required. Please allow in Settings."
            ])
        }
        
        // Perform the trim and get the output URL
        let outputURL = try await performTrim(url: localFileURL, startTime: startTime, endTime: endTime)
        
        // Successfully saved
        logger.info("Video successfully trimmed and saved to \(outputURL)")
        return true
    }
    
    /// Check for Photo Library permission
    /// - Returns: Authorization status
    /// - Throws: Error during permission check
    private func checkPhotosPermission() async throws -> PHAuthorizationStatus {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<PHAuthorizationStatus, Error>) in
            PHPhotoLibrary.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
    
    /// Perform the trim operation
    /// - Parameters:
    ///   - url: The URL of the video file to trim
    ///   - startTime: Start time for the trim
    ///   - endTime: End time for the trim
    /// - Returns: URL of the trimmed video
    /// - Throws: Error if trim fails
    private func performTrim(url: URL, startTime: CMTime, endTime: CMTime) async throws -> URL {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            trimManager.trimVideo(url: url, startTime: startTime, endTime: endTime) { result in
                switch result {
                case .success(let outputURL):
                    self.logger.info("Trim successful. Output URL: \(outputURL)")
                    continuation.resume(returning: outputURL)
                case .failure(let error):
                    self.logger.error("Trim failed: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}