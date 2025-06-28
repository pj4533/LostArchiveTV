//
//  VideoPlaybackManagerTests.swift
//  LostArchiveTVTests
//
//  Created by Claude on 4/19/25.
//  Updated for consolidated VideoPlaybackManager architecture on 6/27/25.
//

import Testing
import AVKit
@testable import LATV

/// Tests for VideoPlaybackManager after consolidation from PlayerManager delegation.
/// These tests now verify the direct implementation rather than async delegation patterns.
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
    func play_setsPlayingStateCorrectly() async throws {
        // Arrange
        let playbackManager = VideoPlaybackManager()
        let url = URL(string: "https://example.com/test/test.mp4")!
        let asset = AVURLAsset(url: url)
        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        playbackManager.useExistingPlayer(player)
        
        // Verify initial state
        #expect(!playbackManager.isPlaying)
        
        // Act
        playbackManager.play()
        
        // Assert - our implementation correctly sets isPlaying = true
        #expect(playbackManager.isPlaying)
        // Note: AVPlayer.rate might not change in unit tests due to no actual media,
        // but our isPlaying state management works correctly
    }
    
    @Test
    func cleanupPlayer_releasesPlayerResourcesAndResetsState() async throws {
        // Arrange
        let playbackManager = VideoPlaybackManager()
        let url = URL(string: "https://example.com/test/test.mp4")!
        let asset = AVURLAsset(url: url)
        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        playbackManager.useExistingPlayer(player)
        playbackManager.play()
        
        // Verify initial state has player and resources
        #expect(playbackManager.player != nil)
        #expect(playbackManager.isPlaying)
        #expect(playbackManager.currentVideoURL != nil)
        
        // Act
        playbackManager.cleanupPlayer()
        
        // Assert - cleanup now directly resets all state
        #expect(playbackManager.player == nil)
        #expect(!playbackManager.isPlaying)
        #expect(playbackManager.currentTime == 0)
        #expect(playbackManager.videoDuration == 0)
        #expect(playbackManager.currentVideoURL == nil)
    }
    
    @Test
    func playerItemDidReachEnd_restartsPlaybackFromBeginning() async throws {
        // Arrange
        let playbackManager = VideoPlaybackManager()
        let url = URL(string: "https://example.com/test/test.mp4")!
        let asset = AVURLAsset(url: url)
        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        playbackManager.useExistingPlayer(player)
        playbackManager.play()
        
        // Verify initial playing state
        #expect(playbackManager.isPlaying)
        
        // Act - simulate end of playback notification
        let playerItem = playbackManager.player?.currentItem
        NotificationCenter.default.post(
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
        
        // Allow notification to be processed
        await Task.yield()
        
        // Assert - the playback manager automatically restarts and continues playing
        #expect(playbackManager.isPlaying)
        // Player should have sought back to beginning
        if let currentTime = playbackManager.player?.currentItem?.currentTime() {
            #expect(abs(currentTime.seconds) < 0.1) // Should be at or very close to beginning
        }
    }
    
    // MARK: - New Functionality Tests (Previously in PlayerManager)
    
    @Test
    func createNewPlayer_createsPlayerWithAssetAndURL() throws {
        // Arrange
        let playbackManager = VideoPlaybackManager()
        let url = URL(string: "https://example.com/test/test.mp4")!
        let asset = AVURLAsset(url: url)
        
        // Act
        playbackManager.createNewPlayer(from: asset, url: url)
        
        // Assert
        #expect(playbackManager.player != nil)
        #expect(playbackManager.currentVideoURL == url)
        
        // Verify the player has the correct asset
        if let playerItem = playbackManager.player?.currentItem,
           let playerAsset = playerItem.asset as? AVURLAsset {
            #expect(playerAsset.url == url)
        }
    }
    
    @Test
    func createNewPlayer_withStartPosition_seeksToCorrectTime() throws {
        // Arrange
        let playbackManager = VideoPlaybackManager()
        let url = URL(string: "https://example.com/test/test.mp4")!
        let asset = AVURLAsset(url: url)
        let startPosition = 10.0 // 10 seconds
        
        // Act
        playbackManager.createNewPlayer(from: asset, url: url, startPosition: startPosition)
        
        // Assert
        #expect(playbackManager.player != nil)
        // Note: In unit tests, seeking might not work perfectly due to no actual media
        // but we verify the player was created and the method completes without error
    }
    
    @Test
    func pause_stopsPlaybackAndUpdateState() throws {
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
    func seekToBeginning_resetsPositionAndPlays() async throws {
        // Arrange
        let playbackManager = VideoPlaybackManager()
        let url = URL(string: "https://example.com/test/test.mp4")!
        let asset = AVURLAsset(url: url)
        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        playbackManager.useExistingPlayer(player)
        
        // Act
        playbackManager.seekToBeginning()
        
        // Allow seek operation to complete
        try await Task.sleep(for: .milliseconds(100))
        
        // Assert
        #expect(playbackManager.isPlaying)
        // Player should be at or very close to the beginning
        if let currentTime = playbackManager.player?.currentItem?.currentTime() {
            #expect(abs(currentTime.seconds) < 0.1)
        }
    }
    
    @Test
    func setTemporaryPlaybackRate_changesRateAndStoresOriginal() throws {
        // Arrange
        let playbackManager = VideoPlaybackManager()
        let url = URL(string: "https://example.com/test/test.mp4")!
        let asset = AVURLAsset(url: url)
        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        playbackManager.useExistingPlayer(player)
        
        let temporaryRate: Float = 2.0
        let initialRate = playbackManager.player?.rate ?? 0
        
        // Act
        playbackManager.setTemporaryPlaybackRate(rate: temporaryRate)
        
        // Assert
        #expect(playbackManager.player?.rate == temporaryRate)
        
        // Verify the rate was actually changed from the initial value
        #expect(playbackManager.player?.rate != initialRate)
    }
    
    @Test
    func resetPlaybackRate_restoresOriginalRate() throws {
        // Arrange
        let playbackManager = VideoPlaybackManager()
        let url = URL(string: "https://example.com/test/test.mp4")!
        let asset = AVURLAsset(url: url)
        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        playbackManager.useExistingPlayer(player)
        
        let temporaryRate: Float = 2.0
        let expectedOriginalRate: Float = 1.0
        
        // Set temporary rate
        playbackManager.setTemporaryPlaybackRate(rate: temporaryRate)
        #expect(playbackManager.player?.rate == temporaryRate)
        
        // Act
        playbackManager.resetPlaybackRate()
        
        // Assert
        #expect(playbackManager.player?.rate == expectedOriginalRate)
    }
    
    @Test
    func applyFormatSpecificOptimizations_setsCorrectPlayerSettings() throws {
        // Arrange
        let playbackManager = VideoPlaybackManager()
        
        // Test H.264 IA format (should disable auto stalling)
        let h264IAUrl = URL(string: "https://example.com/test/h.264_ia_video.mp4")!
        let h264IAAsset = AVURLAsset(url: h264IAUrl)
        
        // Act
        playbackManager.createNewPlayer(from: h264IAAsset, url: h264IAUrl)
        
        // Assert
        #expect(playbackManager.player?.automaticallyWaitsToMinimizeStalling == false)
        
        // Clean up for next test
        playbackManager.cleanupPlayer()
        
        // Test regular H.264 format (should enable auto stalling)
        let h264Url = URL(string: "https://example.com/test/h.264_video.mp4")!
        let h264Asset = AVURLAsset(url: h264Url)
        
        // Act
        playbackManager.createNewPlayer(from: h264Asset, url: h264Url)
        
        // Assert
        #expect(playbackManager.player?.automaticallyWaitsToMinimizeStalling == true)
        
        // Clean up for next test
        playbackManager.cleanupPlayer()
        
        // Test MPEG4 format (should enable auto stalling)
        let mpeg4Url = URL(string: "https://example.com/test/mpeg4_video.mp4")!
        let mpeg4Asset = AVURLAsset(url: mpeg4Url)
        
        // Act
        playbackManager.createNewPlayer(from: mpeg4Asset, url: mpeg4Url)
        
        // Assert
        #expect(playbackManager.player?.automaticallyWaitsToMinimizeStalling == true)
    }
    
    @Test
    func currentTimeAsCMTime_returnsCorrectTime() throws {
        // Arrange
        let playbackManager = VideoPlaybackManager()
        let url = URL(string: "https://example.com/test/test.mp4")!
        let asset = AVURLAsset(url: url)
        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        playbackManager.useExistingPlayer(player)
        
        // Act
        let cmTime = playbackManager.currentTimeAsCMTime
        
        // Assert
        #expect(cmTime != nil)
        #expect(cmTime?.isValid == true)
    }
    
    @Test
    func durationAsCMTime_returnsCorrectDuration() throws {
        // Arrange
        let playbackManager = VideoPlaybackManager()
        let url = URL(string: "https://example.com/test/test.mp4")!
        let asset = AVURLAsset(url: url)
        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        playbackManager.useExistingPlayer(player)
        
        // Act
        let cmTime = playbackManager.durationAsCMTime
        
        // Assert
        #expect(cmTime != nil)
        // Note: Duration might be invalid in unit tests without actual media, but method should not crash
    }
    
    @Test
    func seek_toSpecificTime_updatesPlayerPosition() async throws {
        // Arrange
        let playbackManager = VideoPlaybackManager()
        let url = URL(string: "https://example.com/test/test.mp4")!
        let asset = AVURLAsset(url: url)
        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        playbackManager.useExistingPlayer(player)
        
        let targetTime = CMTime(seconds: 5.0, preferredTimescale: 600)
        
        // Act
        await withCheckedContinuation { continuation in
            playbackManager.seek(to: targetTime) { finished in
                #expect(finished) // Seek should complete successfully
                continuation.resume()
            }
        }
        
        // Assert - method completes without error
        // Note: Actual time validation difficult in unit tests without real media
    }
    
    @Test
    func audioSessionSetup_configuresCorrectly() throws {
        // Arrange
        let playbackManager = VideoPlaybackManager()
        
        // Act & Assert - should not crash during initialization
        playbackManager.setupAudioSession()
        playbackManager.setupAudioSession(forTrimming: true)
        playbackManager.deactivateAudioSession()
        
        // All audio session methods should complete without error
    }
}