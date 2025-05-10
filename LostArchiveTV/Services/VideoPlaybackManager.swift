//
//  VideoPlaybackManager.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import Foundation
import AVFoundation
import OSLog

class VideoPlaybackManager: ObservableObject {
    // Use the centralized PlayerManager
    let playerManager = PlayerManager()
    
    // Published properties that mirror PlayerManager values
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var videoDuration: Double = 0
    
    init() {
        // Set up observation of the player manager's published properties
        setupObservations()
        
        // Configure audio session
        setupAudioSession()
    }
    
    private func setupObservations() {
        // Observe isPlaying
        Task {
            for await isPlaying in playerManager.$isPlaying.values {
                await MainActor.run {
                    self.isPlaying = isPlaying
                }
            }
        }
        
        // Observe currentTime
        Task {
            for await currentTime in playerManager.$currentTime.values {
                await MainActor.run {
                    self.currentTime = currentTime
                }
            }
        }
        
        // Observe videoDuration
        Task {
            for await videoDuration in playerManager.$videoDuration.values {
                await MainActor.run {
                    self.videoDuration = videoDuration
                }
            }
        }
    }
    
    // MARK: - Proxied Player Properties
    var player: AVPlayer? {
        get { playerManager.player }
        set {
            if let newPlayer = newValue {
                playerManager.useExistingPlayer(newPlayer)
            } else {
                playerManager.cleanupPlayer()
            }
        }
    }
    
    var currentVideoURL: URL? {
        return playerManager.currentVideoURL
    }
    
    var currentTimeAsCMTime: CMTime? {
        return playerManager.currentTimeAsCMTime
    }
    
    var durationAsCMTime: CMTime? {
        return playerManager.durationAsCMTime
    }
    
    // MARK: - Proxied Methods
    
    func setupAudioSession() {
        playerManager.setupAudioSession()
    }
    
    func useExistingPlayer(_ player: AVPlayer) {
        let playerPointer = String(describing: ObjectIdentifier(player))
        Logger.videoPlayback.debug("🎮 VP_MANAGER: Delegating useExistingPlayer for player \(playerPointer)")
        playerManager.useExistingPlayer(player)
    }

    func play() {
        if let player = playerManager.player {
            let playerPointer = String(describing: ObjectIdentifier(player))
            let itemStatus = player.currentItem?.status.rawValue ?? -1
            Logger.videoPlayback.debug("▶️ VP_MANAGER: Play requested for player \(playerPointer), item status: \(itemStatus)")
        } else {
            Logger.videoPlayback.warning("▶️ VP_MANAGER: Play requested but player is nil")
        }
        playerManager.play()
    }

    func pause() {
        if let player = playerManager.player {
            let playerPointer = String(describing: ObjectIdentifier(player))
            let itemStatus = player.currentItem?.status.rawValue ?? -1
            Logger.videoPlayback.debug("⏸️ VP_MANAGER: Pause requested for player \(playerPointer), item status: \(itemStatus)")
        } else {
            Logger.videoPlayback.warning("⏸️ VP_MANAGER: Pause requested but player is nil")
        }
        playerManager.pause()
    }
    
    func seek(to time: CMTime, completion: ((Bool) -> Void)? = nil) {
        playerManager.seek(to: time, completion: completion)
    }
    
    func seekToBeginning() {
        playerManager.seekToBeginning()
    }
    
    func monitorBufferStatus(for playerItem: AVPlayerItem) async {
        await playerManager.monitorBufferStatus(for: playerItem)
    }
    
    func cleanupPlayer() {
        if let player = playerManager.player {
            let playerPointer = String(describing: ObjectIdentifier(player))
            let itemStatus = player.currentItem?.status.rawValue ?? -1
            Logger.videoPlayback.debug("🧹 VP_MANAGER: Delegating cleanupPlayer for player \(playerPointer), item status: \(itemStatus)")
        } else {
            Logger.videoPlayback.debug("🧹 VP_MANAGER: Delegating cleanupPlayer but player is already nil")
        }
        playerManager.cleanupPlayer()
    }
    
    func setTemporaryPlaybackRate(rate: Float) {
        playerManager.setTemporaryPlaybackRate(rate: rate)
    }
    
    func resetPlaybackRate() {
        playerManager.resetPlaybackRate()
    }
}