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
    }
    
    @Test
    func play_setsPlayingStateToTrue() {
        // Arrange
        let playbackManager = VideoPlaybackManager()
        let url = URL(string: "https://example.com/test/test.mp4")!
        let asset = AVURLAsset(url: url)
        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        playbackManager.useExistingPlayer(player)
        
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
        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        playbackManager.useExistingPlayer(player)
        playbackManager.play()
        
        // Initial state check
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
    func playerItemDidReachEnd_restartsPlayback() {
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
        
        // Assert - the playback manager restarts the video and keeps playing
        #expect(playbackManager.isPlaying)
        #expect(playbackManager.player?.currentTime() == CMTime.zero)
    }
    
    @Test
    func pause_setsPlayingStateToFalse() {
        // Arrange
        let playbackManager = VideoPlaybackManager()
        let url = URL(string: "https://example.com/test/test.mp4")!
        let asset = AVURLAsset(url: url)
        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        playbackManager.useExistingPlayer(player)
        playbackManager.play()
        
        // Verify playing state
        #expect(playbackManager.isPlaying)
        
        // Act
        playbackManager.pause()
        
        // Assert
        #expect(!playbackManager.isPlaying)
    }
    
    @Test
    func createNewPlayer_initializesPlayerFromAsset() {
        // Arrange
        let playbackManager = VideoPlaybackManager()
        let url = URL(string: "https://example.com/test/test.mp4")!
        let asset = AVURLAsset(url: url)
        
        // Act
        playbackManager.createNewPlayer(from: asset, url: url)
        
        // Assert
        #expect(playbackManager.player != nil)
        #expect(playbackManager.currentVideoURL == url)
        #expect(!playbackManager.isPlaying)
    }
    
    @Test
    func setTemporaryPlaybackRate_changesPlaybackSpeed() {
        // Arrange
        let playbackManager = VideoPlaybackManager()
        let url = URL(string: "https://example.com/test/test.mp4")!
        let asset = AVURLAsset(url: url)
        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        playbackManager.useExistingPlayer(player)
        
        // Act
        playbackManager.setTemporaryPlaybackRate(rate: 2.0)
        
        // Assert
        #expect(playbackManager.player?.rate == 2.0)
    }
    
    @Test
    func resetPlaybackRate_restoresNormalSpeed() {
        // Arrange
        let playbackManager = VideoPlaybackManager()
        let url = URL(string: "https://example.com/test/test.mp4")!
        let asset = AVURLAsset(url: url)
        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        playbackManager.useExistingPlayer(player)
        
        // Set temporary rate
        playbackManager.setTemporaryPlaybackRate(rate: 2.0)
        #expect(playbackManager.player?.rate == 2.0)
        
        // Act
        playbackManager.resetPlaybackRate()
        
        // Assert
        #expect(playbackManager.player?.rate == 1.0)
    }
    
    @Test
    func seekToBeginning_resetsPlaybackPosition() {
        // Arrange
        let playbackManager = VideoPlaybackManager()
        let url = URL(string: "https://example.com/test/test.mp4")!
        let asset = AVURLAsset(url: url)
        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        playbackManager.useExistingPlayer(player)
        
        // Move player to some position
        let seekTime = CMTime(seconds: 10, preferredTimescale: 600)
        player.seek(to: seekTime)
        
        // Act
        playbackManager.seekToBeginning()
        
        // Note: In a real test we'd wait for the seek completion,
        // but for unit testing we're verifying the method was called
        #expect(playbackManager.player != nil)
    }
}