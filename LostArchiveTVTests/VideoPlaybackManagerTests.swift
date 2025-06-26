//
//  VideoPlaybackManagerTests.swift
//  LostArchiveTVTests
//
//  Created by Claude on 4/19/25.
//

import Testing
import AVKit
@testable import LATV

struct VideoPlaybackManagerTests {
    
    @Test
    func useExistingPlayer_setsPlayerDirectly() {
        // Arrange
        let playbackManager = VideoPlaybackManager()
        let url = URL(string: "https://example.com/test/test.mp4")!
        let asset = AVURLAsset(url: url)
        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        
        // Act
        playbackManager.useExistingPlayer(player)
        
        // Assert
        #expect(playbackManager.player != nil)
        #expect(playbackManager.currentVideoURL == url)
    }
    
    @Test
    func createNewPlayer_createsPlayerFromAsset() {
        // Arrange
        let playbackManager = VideoPlaybackManager()
        let url = URL(string: "https://example.com/test/test.mp4")!
        let asset = AVURLAsset(url: url)
        
        // Act
        playbackManager.createNewPlayer(from: asset, url: url)
        
        // Assert
        #expect(playbackManager.player != nil)
        #expect(playbackManager.currentVideoURL == url)
    }
    
    @Test
    func createNewPlayer_withStartPosition_seeksToPosition() {
        // Arrange
        let playbackManager = VideoPlaybackManager()
        let url = URL(string: "https://example.com/test/test.mp4")!
        let asset = AVURLAsset(url: url)
        let startPosition = 10.0
        
        // Act
        playbackManager.createNewPlayer(from: asset, url: url, startPosition: startPosition)
        
        // Assert
        #expect(playbackManager.player != nil)
        #expect(playbackManager.currentVideoURL == url)
        // The player will seek to the start position, but we can't easily test the exact time
        // since seeking is asynchronous
    }
    
    @Test
    func play_callsPlayerPlay() {
        // Arrange
        let playbackManager = VideoPlaybackManager()
        let url = URL(string: "https://example.com/test/test.mp4")!
        let asset = AVURLAsset(url: url)
        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        playbackManager.useExistingPlayer(player)
        
        // Act
        playbackManager.play()
        
        // Assert
        #expect(playbackManager.isPlaying == true)
        #expect(playbackManager.player?.rate == 1.0)
    }
    
    @Test
    func pause_callsPlayerPause() {
        // Arrange
        let playbackManager = VideoPlaybackManager()
        let url = URL(string: "https://example.com/test/test.mp4")!
        let asset = AVURLAsset(url: url)
        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        playbackManager.useExistingPlayer(player)
        playbackManager.play()
        
        // Act
        playbackManager.pause()
        
        // Assert
        #expect(playbackManager.isPlaying == false)
        #expect(playbackManager.player?.rate == 0.0)
    }
    
    @Test
    func cleanupPlayer_releasesPlayerResources() {
        // Arrange
        let playbackManager = VideoPlaybackManager()
        let url = URL(string: "https://example.com/test/test.mp4")!
        let asset = AVURLAsset(url: url)
        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        playbackManager.useExistingPlayer(player)
        playbackManager.play()
        
        // Initial state check
        #expect(playbackManager.player != nil)
        #expect(playbackManager.isPlaying)
        #expect(playbackManager.currentVideoURL != nil)
        
        // Act
        playbackManager.cleanupPlayer()
        
        // Assert - cleanupPlayer() directly sets all state
        #expect(playbackManager.player == nil)
        #expect(playbackManager.isPlaying == false)
        #expect(playbackManager.currentTime == 0)
        #expect(playbackManager.videoDuration == 0)
        #expect(playbackManager.currentVideoURL == nil)
    }
    
    @Test
    func seekToBeginning_seeksToZeroAndPlays() async {
        // Arrange
        let playbackManager = VideoPlaybackManager()
        let url = URL(string: "https://example.com/test/test.mp4")!
        let asset = AVURLAsset(url: url)
        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        playbackManager.useExistingPlayer(player)
        
        // Act
        playbackManager.seekToBeginning()
        
        // Wait a moment for the seek to complete
        try? await Task.sleep(for: .milliseconds(100))
        
        // Assert - the implementation sets isPlaying to true in the completion handler
        #expect(playbackManager.isPlaying == true)
    }
    
    @Test
    func setAndResetPlaybackRate_managesRateCorrectly() {
        // Arrange
        let playbackManager = VideoPlaybackManager()
        let url = URL(string: "https://example.com/test/test.mp4")!
        let asset = AVURLAsset(url: url)
        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        playbackManager.useExistingPlayer(player)
        playbackManager.play()
        
        let testRate: Float = 2.0
        
        // Act - set temporary rate
        playbackManager.setTemporaryPlaybackRate(rate: testRate)
        
        // Assert temporary rate is set
        #expect(playbackManager.player?.rate == testRate)
        
        // Act - reset rate
        playbackManager.resetPlaybackRate()
        
        // Assert rate is reset (should be 1.0 as that's the normal rate)
        #expect(playbackManager.player?.rate == 1.0)
    }
    
    @Test
    func playerItemDidReachEnd_restartsPlayback() async {
        // Arrange
        let playbackManager = VideoPlaybackManager()
        let url = URL(string: "https://example.com/test/test.mp4")!
        let asset = AVURLAsset(url: url)
        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        playbackManager.useExistingPlayer(player)
        playbackManager.play()
        
        // Initial state check
        #expect(playbackManager.isPlaying)
        
        // Act - simulate end of playback notification
        let playerItem = playbackManager.player?.currentItem
        NotificationCenter.default.post(
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
        
        // Wait a moment for the notification to be processed
        try? await Task.sleep(for: .milliseconds(100))
        
        // Assert - the playback manager restarts the video and keeps playing
        #expect(playbackManager.isPlaying == true)
        #expect(playbackManager.player?.rate == 1.0)
    }
    
    @Test
    func audioSessionSetup_configuresCorrectly() {
        // Arrange
        let playbackManager = VideoPlaybackManager()
        
        // Act & Assert - should not throw
        playbackManager.setupAudioSession()
        playbackManager.setupAudioSession(forTrimming: true)
        playbackManager.deactivateAudioSession()
    }
    
    @Test
    func computedProperties_returnCorrectValues() {
        // Arrange
        let playbackManager = VideoPlaybackManager()
        let url = URL(string: "https://example.com/test/test.mp4")!
        let asset = AVURLAsset(url: url)
        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        playbackManager.useExistingPlayer(player)
        
        // Assert
        #expect(playbackManager.currentTimeAsCMTime != nil)
        #expect(playbackManager.durationAsCMTime != nil)
        #expect(playbackManager.currentVideoURL == url)
    }
}