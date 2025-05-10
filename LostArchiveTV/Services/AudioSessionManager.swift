import Foundation
import AVFoundation
import OSLog

/// Manages audio session configuration for specific use cases
class AudioSessionManager {
    private let logger = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "audio")
    
    /// Configure audio session for video trimming
    func configureForTrimming() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // First try to deactivate any existing session
            try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: .duckOthers)
            try audioSession.setActive(true)
            logger.debug("📊 AUDIO_DIAG: Set up dedicated audio session for trim view, category=\(audioSession.category.rawValue)")
        } catch {
            logger.error("📊 AUDIO_DIAG: [ERROR] Failed to set up trim view audio session: \(error)")
        }
    }
    
    /// Deactivate audio session when finished
    func deactivate() {
        do {
            // Get current state for debugging
            let audioSession = AVAudioSession.sharedInstance()
            let currentCategory = audioSession.category.rawValue
            let currentMode = audioSession.mode.rawValue
            
            // Deactivate our audio session
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            logger.debug("📊 AUDIO_DIAG: Deactivated audio session (was category=\(currentCategory), mode=\(currentMode))")
        } catch {
            logger.error("📊 AUDIO_DIAG: [ERROR] Failed to deactivate audio session: \(error)")
        }
    }
    
    /// Configure audio session for general video playback
    func configureForPlayback() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Log current state
            logger.debug("📊 AUDIO_DIAG: Audio session before configuring: category=\(audioSession.category.rawValue), mode=\(audioSession.mode.rawValue), other playing=\(audioSession.isOtherAudioPlaying)")
            
            // First try to deactivate any existing session
            try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            
            try audioSession.setCategory(.playback, mode: .moviePlayback)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            logger.info("📊 AUDIO_DIAG: Audio session configured for playback, result: category=\(audioSession.category.rawValue), other playing=\(audioSession.isOtherAudioPlaying)")
        } catch {
            logger.error("📊 AUDIO_DIAG: [ERROR] Failed to configure audio session: \(error.localizedDescription)")
        }
    }
    
    /// Returns a string describing the current audio session state for debugging
    func describeCurrentState() -> String {
        let audioSession = AVAudioSession.sharedInstance()
        let category = audioSession.category.rawValue
        let mode = audioSession.mode.rawValue
        let isOtherPlaying = audioSession.isOtherAudioPlaying
        return "Category=\(category), Mode=\(mode), OtherPlaying=\(isOtherPlaying)"
    }
}