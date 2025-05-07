//
//  PlayerManagerRateTests.swift
//  LostArchiveTVTests
//
//  Created by Claude on 5/6/25.
//

import AVKit
import Testing

@MainActor
struct PlayerManagerRateTests {
    
    @Test("`setTemporaryPlaybackRate` changes playback rate properly")
    func testSetTemporaryPlaybackRate() async {
        // Arrange
        let playerManager = PlayerManager()
        let testUrl = URL(string: "https://example.com/video.mp4")!
        let asset = AVURLAsset(url: testUrl)
        
        // Create a new player with default rate 1.0
        playerManager.createNewPlayer(from: asset, url: testUrl)
        
        // Act
        playerManager.setTemporaryPlaybackRate(rate: 2.0)
        
        // Assert
        #expect(playerManager.player?.rate == 2.0)
        #expect(playerManager.normalPlaybackRate == 1.0) // Stored original rate
    }
    
    @Test("`resetPlaybackRate` restores original rate")
    func testResetPlaybackRate() async {
        // Arrange
        let playerManager = PlayerManager()
        let testUrl = URL(string: "https://example.com/video.mp4")!
        let asset = AVURLAsset(url: testUrl)
        
        // Create a new player with default rate 1.0
        playerManager.createNewPlayer(from: asset, url: testUrl)
        playerManager.play() // Ensure player is playing
        
        // Set temporary rate
        playerManager.setTemporaryPlaybackRate(rate: 2.0)
        
        // Act
        playerManager.resetPlaybackRate()
        
        // Assert
        #expect(playerManager.player?.rate == 1.0) // Playback rate is restored
    }
    
    @Test("`setTemporaryPlaybackRate` preserves non-standard initial rates")
    func testPreserveNonStandardRates() async {
        // Arrange
        let playerManager = PlayerManager()
        let testUrl = URL(string: "https://example.com/video.mp4")!
        let asset = AVURLAsset(url: testUrl)
        
        // Create a new player
        playerManager.createNewPlayer(from: asset, url: testUrl)
        playerManager.play() // Ensure player is playing
        
        // Set an unusual initial rate
        playerManager.player?.rate = 0.75
        
        // Act
        playerManager.setTemporaryPlaybackRate(rate: 2.0)
        let tempRate = playerManager.player?.rate
        playerManager.resetPlaybackRate()
        
        // Assert
        #expect(tempRate == 2.0) // Temporary rate was applied
        #expect(playerManager.player?.rate == 0.75) // Original unusual rate is restored
    }
    
    @Test("Multiple temporary rate changes work correctly")
    func testMultipleRateChanges() async {
        // Arrange
        let playerManager = PlayerManager()
        let testUrl = URL(string: "https://example.com/video.mp4")!
        let asset = AVURLAsset(url: testUrl)
        
        // Create a new player
        playerManager.createNewPlayer(from: asset, url: testUrl)
        playerManager.play() // Ensure player is playing
        
        // Act & Assert - First rate change
        playerManager.setTemporaryPlaybackRate(rate: 1.5)
        #expect(playerManager.player?.rate == 1.5)
        
        // Act & Assert - Second rate change
        playerManager.setTemporaryPlaybackRate(rate: 2.0)
        #expect(playerManager.player?.rate == 2.0)
        #expect(playerManager.normalPlaybackRate == 1.0) // Original rate is preserved
        
        // Act & Assert - Reset to original
        playerManager.resetPlaybackRate()
        #expect(playerManager.player?.rate == 1.0)
    }
}