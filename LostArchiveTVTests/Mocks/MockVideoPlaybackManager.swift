//
//  MockVideoPlaybackManager.swift
//  LostArchiveTVTests
//
//  Created by Claude on 4/19/25.
//

import Foundation
import AVKit
@testable import LostArchiveTV

class MockVideoPlaybackManager {
    var setupPlayerCalled = false
    var playCalled = false
    var seekCalled = false
    var cleanupPlayerCalled = false
    var monitorBufferStatusCalled = false
    var setupAudioSessionCalled = false
    
    var mockPlayer: AVPlayer? = AVPlayer()
    var mockDuration: Double = 120.0
    var isPlaying = false
    var currentTime: Double = 0
    var videoDuration: Double = 120.0
    
    var player: AVPlayer? {
        return mockPlayer
    }
    
    func setupPlayer(with asset: AVAsset) {
        setupPlayerCalled = true
    }
    
    func play() {
        playCalled = true
        isPlaying = true
    }
    
    func seek(to time: CMTime, completion: ((Bool) -> Void)? = nil) {
        seekCalled = true
        completion?(true)
    }
    
    func monitorBufferStatus(for playerItem: AVPlayerItem) async {
        monitorBufferStatusCalled = true
    }
    
    func setupAudioSession() {
        setupAudioSessionCalled = true
    }
    
    func cleanupPlayer() {
        cleanupPlayerCalled = true
        mockPlayer = nil
        isPlaying = false
    }
}