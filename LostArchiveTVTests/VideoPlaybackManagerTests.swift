//
//  VideoPlaybackManagerTests.swift
//  LostArchiveTVTests
//
//  Created by Claude on 4/19/25.
//

import Testing
import AVKit
@testable import LostArchiveTV

struct VideoPlaybackManagerTests {
    
    @Test
    func setupPlayer_createsPlayerWithAsset() {
        // Arrange
        let playbackManager = VideoPlaybackManager()
        let url = URL(string: "https://example.com/test/test.mp4")!
        let asset = AVURLAsset(url: url)
        
        // Act
        playbackManager.setupPlayer(with: asset)
        
        // Assert
        #expect(playbackManager.player != nil)
    }
    
    @Test
    func play_setsPlayingStateToTrue() {
        // Arrange
        let playbackManager = VideoPlaybackManager()
        let url = URL(string: "https://example.com/test/test.mp4")!
        let asset = AVURLAsset(url: url)
        playbackManager.setupPlayer(with: asset)
        
        // Initial state
        #expect(!playbackManager.isPlaying)
        
        // Act
        playbackManager.play()
        
        // Assert
        #expect(playbackManager.isPlaying)
    }
    
    @Test
    func cleanupPlayer_releasesPlayerResources() {
        // Arrange
        let playbackManager = VideoPlaybackManager()
        let url = URL(string: "https://example.com/test/test.mp4")!
        let asset = AVURLAsset(url: url)
        playbackManager.setupPlayer(with: asset)
        playbackManager.play()
        
        // Initial state
        #expect(playbackManager.player != nil)
        #expect(playbackManager.isPlaying)
        
        // Act
        playbackManager.cleanupPlayer()
        
        // Assert
        #expect(playbackManager.player == nil)
        #expect(!playbackManager.isPlaying)
        #expect(playbackManager.currentTime == 0)
        #expect(playbackManager.videoDuration == 0)
    }
    
    @Test
    func playerItemDidReachEnd_updatesPlayingState() {
        // Arrange
        let playbackManager = VideoPlaybackManager()
        let url = URL(string: "https://example.com/test/test.mp4")!
        let asset = AVURLAsset(url: url)
        playbackManager.setupPlayer(with: asset)
        playbackManager.play()
        
        // Initial state
        #expect(playbackManager.isPlaying)
        
        // Act - simulate end of playback notification
        let playerItem = playbackManager.player?.currentItem
        NotificationCenter.default.post(
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
        
        // Assert
        #expect(!playbackManager.isPlaying)
    }
}