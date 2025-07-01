//
//  VideoPlaybackManagerDelegate.swift
//  LostArchiveTV
//

import AVFoundation

/// Delegate protocol for receiving video playback error notifications
protocol VideoPlaybackManagerDelegate: AnyObject {
    /// Called when the player encounters an error during playback
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - player: The AVPlayer instance that encountered the error
    func playerEncounteredError(_ error: Error, for player: AVPlayer)
}