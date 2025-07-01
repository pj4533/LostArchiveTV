//
//  VideoPlaybackManager+ContentFailure.swift
//  LostArchiveTV
//
//  Created by VideoPlaybackManager extension on 7/1/25.
//

import Foundation
import AVFoundation
import OSLog

// MARK: - Content Failure Detection
extension VideoPlaybackManager {
    
    /// Sets up observations for content failures on the given player item
    internal func setupContentFailureObservations(for playerItem: AVPlayerItem) {
        Logger.videoPlayback.debug("🔍 VP_MANAGER: Setting up content failure observations")
        
        // Observe AVPlayerItem status changes
        statusObservation = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self = self else { return }
            
            if item.status == .failed {
                Logger.videoPlayback.error("❌ VP_MANAGER: Player item status changed to failed")
                if let error = item.error {
                    self.handlePlayerItemError(error)
                }
            }
        }
        
        // Observe failed to play to end time notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemFailedToPlayToEndTime),
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem
        )
    }
    
    /// Handler for when playback fails to reach the end
    @objc private func playerItemFailedToPlayToEndTime(notification: Notification) {
        Logger.videoPlayback.error("❌ VP_MANAGER: Player item failed to play to end time")
        
        if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
            handlePlayerItemError(error)
        }
    }
    
    /// Handles player item errors and determines if they are content failures
    private func handlePlayerItemError(_ error: Error) {
        Logger.videoPlayback.error("❌ VP_MANAGER: Handling player item error: \(error.localizedDescription)")
        
        if isContentFailure(error) {
            Logger.videoPlayback.error("❌ VP_MANAGER: Detected content failure - notifying delegate")
            if let player = player {
                delegate?.playerEncounteredError(error, for: player)
            }
        } else {
            Logger.videoPlayback.info("🔍 VP_MANAGER: Error is not a content failure (likely network/buffering issue)")
        }
    }
    
    /// Determines if an error represents a content failure vs a network issue
    /// - Parameter error: The error to analyze
    /// - Returns: true if this is a content failure that should trigger a skip
    private func isContentFailure(_ error: Error) -> Bool {
        let nsError = error as NSError
        
        Logger.videoPlayback.debug("🔍 VP_MANAGER: Analyzing error - domain: \(nsError.domain), code: \(nsError.code)")
        
        // Check for HTTP 404 errors
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorFileDoesNotExist {
            Logger.videoPlayback.debug("❌ VP_MANAGER: Content failure - HTTP 404")
            return true
        }
        
        // Check for specific AVFoundation errors that indicate content issues
        if nsError.domain == AVFoundationErrorDomain {
            switch nsError.code {
            case AVError.mediaServicesWereReset.rawValue:
                Logger.videoPlayback.debug("⚠️ VP_MANAGER: Media services reset - not a content failure")
                return false
            case AVError.unknown.rawValue:
                Logger.videoPlayback.debug("⚠️ VP_MANAGER: Unknown error - checking if content failure")
                // For unknown errors, check the description for content failure patterns
                break
            case AVError.decoderNotFound.rawValue:
                Logger.videoPlayback.debug("❌ VP_MANAGER: Content failure - Decoder not found")
                return true
            case AVError.decoderTemporarilyUnavailable.rawValue:
                // This could be temporary, but if it persists it's likely a content issue
                Logger.videoPlayback.debug("⚠️ VP_MANAGER: Decoder temporarily unavailable - treating as content failure")
                return true
            case AVError.failedToParse.rawValue:
                Logger.videoPlayback.debug("❌ VP_MANAGER: Content failure - Failed to parse")
                return true
            case AVError.fileFormatNotRecognized.rawValue:
                Logger.videoPlayback.debug("❌ VP_MANAGER: Content failure - File format not recognized")
                return true
            case AVError.unsupportedOutputSettings.rawValue:
                Logger.videoPlayback.debug("❌ VP_MANAGER: Content failure - Unsupported output settings")
                return true
            default:
                // Check for HTTP status codes in userInfo
                if let httpStatusCode = nsError.userInfo["HTTPStatusCode"] as? Int {
                    if httpStatusCode == 404 || httpStatusCode == 410 {
                        Logger.videoPlayback.debug("❌ VP_MANAGER: Content failure - HTTP \(httpStatusCode)")
                        return true
                    }
                }
                // Check for underlying errors
                if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                    Logger.videoPlayback.debug("🔍 VP_MANAGER: Checking underlying error - domain: \(underlyingError.domain), code: \(underlyingError.code)")
                    // Recursively check the underlying error
                    return isContentFailure(underlyingError)
                }
            }
        }
        
        // Check for Core Media errors that indicate content issues
        if nsError.domain == "CoreMediaErrorDomain" {
            switch nsError.code {
            case -12865: // kCMFormatDescriptionError_ValueNotAvailable
                Logger.videoPlayback.debug("❌ VP_MANAGER: Content failure - Core Media format error")
                return true
            case -12318: // kCoreMediaError_Invalidated
                Logger.videoPlayback.debug("❌ VP_MANAGER: Content failure - Core Media invalidated")
                return true
            default:
                break
            }
        }
        
        // Check error description for known content failure patterns
        let errorDescription = error.localizedDescription.lowercased()
        let contentFailurePatterns = [
            "404",
            "not found",
            "file does not exist",
            "unsupported",
            "invalid",
            "corrupted",
            "malformed",
            "cannot decode",
            "format error"
        ]
        
        for pattern in contentFailurePatterns {
            if errorDescription.contains(pattern) {
                Logger.videoPlayback.debug("❌ VP_MANAGER: Content failure - matched pattern '\(pattern)'")
                return true
            }
        }
        
        // Default to false - assume it's a network/buffering issue
        return false
    }
}