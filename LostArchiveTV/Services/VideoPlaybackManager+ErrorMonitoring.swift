//
//  VideoPlaybackManager+ErrorMonitoring.swift
//  LostArchiveTV
//
//  Created by Claude on 2025-07-01.
//

import Foundation
import AVFoundation
import OSLog
import Combine

// MARK: - Error Monitoring Extension
extension VideoPlaybackManager {
    
    // MARK: - Error Detection
    
    /// Determines if an error represents an unrecoverable content failure
    /// - Parameter error: The error to evaluate
    /// - Returns: true if the error indicates a permanent content failure that cannot be recovered
    func isUnrecoverableContentError(_ error: Error) -> Bool {
        let logger = Logger(subsystem: "com.lostarchive.tv", category: "ContentErrors")
        
        // Check for AVFoundation specific errors
        if let avError = error as? AVError {
            switch avError.code {
            case .contentIsNotAuthorized,
                 .contentIsProtected,
                 .fileFormatNotRecognized,
                 .failedToParse,
                 .noLongerPlayable,
                 .incompatibleAsset,
                 .operationNotSupportedForAsset:
                logger.debug("🚫 VP_MANAGER: Detected unrecoverable AVError: \(avError.code.rawValue) - \(avError.localizedDescription)")
                return true
            default:
                logger.debug("⚠️ VP_MANAGER: AVError \(avError.code.rawValue) is potentially recoverable")
                return false
            }
        }
        
        // Check for NSError with specific error codes
        let nsError = error as NSError
        
        // Check URLError domain for permanent failures
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorFileDoesNotExist,
                 NSURLErrorNoPermissionsToReadFile,
                 NSURLErrorDataNotAllowed:
                logger.debug("🚫 VP_MANAGER: Detected unrecoverable URLError: \(nsError.code) - \(nsError.localizedDescription)")
                return true
            default:
                // Network errors like timeout, connection lost, etc. are recoverable
                logger.debug("⚠️ VP_MANAGER: URLError \(nsError.code) is potentially recoverable")
                return false
            }
        }
        
        // Check for specific error descriptions that indicate content issues
        let errorDescription = error.localizedDescription.lowercased()
        let unrecoverablePatterns = [
            "format is not supported",
            "file type is not supported",
            "could not decode",
            "cannot decode",
            "not compatible",
            "invalid",
            "corrupted",
            "damaged"
        ]
        
        for pattern in unrecoverablePatterns {
            if errorDescription.contains(pattern) {
                logger.debug("🚫 VP_MANAGER: Error description indicates unrecoverable content issue: \(error.localizedDescription)")
                return true
            }
        }
        
        logger.debug("⚠️ VP_MANAGER: Error is potentially recoverable: \(error.localizedDescription)")
        return false
    }
    
    /// Handles content failures silently by logging and notifying observers
    /// - Parameter error: The content error that occurred
    func handleContentFailureSilently(error: Error) {
        let logger = Logger(subsystem: "com.lostarchive.tv", category: "ContentErrors")
        
        // Log the error with detailed information
        logger.error("🚫 VP_MANAGER: Content failure detected for URL: \(self._currentVideoURL?.absoluteString ?? "unknown")")
        logger.error("🚫 VP_MANAGER: Error type: \(type(of: error))")
        logger.error("🚫 VP_MANAGER: Error description: \(error.localizedDescription)")
        
        if let avError = error as? AVError {
            logger.error("🚫 VP_MANAGER: AVError code: \(avError.code.rawValue)")
        } else {
            let nsError = error as NSError
            logger.error("🚫 VP_MANAGER: Error domain: \(nsError.domain), code: \(nsError.code)")
        }
        
        // Post notification for view models to handle the failure
        NotificationCenter.default.post(
            name: .playerEncounteredUnrecoverableError,
            object: self,
            userInfo: ["error": error, "url": _currentVideoURL as Any]
        )
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let playerEncounteredUnrecoverableError = Notification.Name("playerEncounteredUnrecoverableError")
}