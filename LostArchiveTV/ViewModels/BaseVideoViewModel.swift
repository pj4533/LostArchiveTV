//
//  BaseVideoViewModel.swift
//  LostArchiveTV
//
//  Created by Claude on 4/25/25.
//

import Foundation
import AVKit
import AVFoundation
import OSLog
import SwiftUI

/// Protocol for view models that provide video functionality
protocol VideoProvider: AnyObject {
    // Get the next video in the sequence
    func getNextVideo() async -> CachedVideo?
    
    // Get the previous video in the sequence
    func getPreviousVideo() async -> CachedVideo?
    
    // Check if we're at the end of the sequence
    func isAtEndOfHistory() -> Bool
    
    // Create a cached video from the current state
    func createCachedVideoFromCurrentState() async -> CachedVideo?
    
    // Add a video to the sequence
    func addVideoToHistory(_ video: CachedVideo)
    
    // Current video properties
    var player: AVPlayer? { get set }
    var currentIdentifier: String? { get set }
    var currentTitle: String? { get set }
    var currentCollection: String? { get set }
    var currentDescription: String? { get set }
    
    // Ensure videos are preloaded/cached
    func ensureVideosAreCached() async
}

/// Base class for video view models that implements common functionality
@MainActor
class BaseVideoViewModel: ObservableObject {
    // MARK: - Common Services
    let playbackManager = VideoPlaybackManager()
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentIdentifier: String?
    @Published var currentCollection: String?
    @Published var currentTitle: String?
    @Published var currentDescription: String?
    @Published var videoDuration: Double = 0
    
    // MARK: - Initialization
    init() {
        setupAudioSession()
        setupDurationObserver()
    }
    
    // MARK: - Setup Functions
    
    func setupAudioSession() {
        playbackManager.setupAudioSession()
    }
    
    func setupDurationObserver() {
        Task {
            for await _ in playbackManager.$videoDuration.values {
                self.videoDuration = playbackManager.videoDuration
            }
        }
    }
    
    // MARK: - Player Controls
    
    var player: AVPlayer? {
        get { playbackManager.player }
        set {
            if let newPlayer = newValue {
                playbackManager.useExistingPlayer(newPlayer)
            } else {
                playbackManager.cleanupPlayer()
            }
        }
    }
    
    func pausePlayback() {
        Logger.videoPlayback.debug("Pausing playback")
        playbackManager.pause()
    }
    
    func resumePlayback() {
        Logger.videoPlayback.debug("Resuming playback")
        playbackManager.play()
    }
    
    func restartVideo() {
        Logger.videoPlayback.info("Restarting video from the beginning")
        playbackManager.seekToBeginning()
    }
    
    func togglePlayPause() {
        if playbackManager.isPlaying {
            pausePlayback()
        } else {
            resumePlayback()
        }
    }
    
    var isPlaying: Bool {
        playbackManager.isPlaying
    }
    
    // MARK: - Video Trimming Support
    
    var currentVideoURL: URL? {
        playbackManager.currentVideoURL
    }
    
    var currentVideoTime: CMTime? {
        playbackManager.currentTimeAsCMTime
    }
    
    var currentVideoDuration: CMTime? {
        playbackManager.durationAsCMTime
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        playbackManager.cleanupPlayer()
    }
}