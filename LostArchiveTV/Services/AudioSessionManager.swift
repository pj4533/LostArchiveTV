import Foundation
import AVFoundation
import OSLog

/// Manages audio session configuration for specific use cases
class AudioSessionManager {
    private let logger = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "audio")
    
    /// Configure audio session for video trimming
    func configureForTrimming() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            logger.debug("Set up dedicated audio session for trim view")
        } catch {
            logger.error("Failed to set up trim view audio session: \(error)")
        }
    }
    
    /// Deactivate audio session when finished
    func deactivate() {
        do {
            // Deactivate our audio session
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            logger.debug("Deactivated audio session")
        } catch {
            logger.error("Failed to deactivate audio session: \(error)")
        }
    }
    
    /// Configure audio session for general video playback
    func configureForPlayback() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            logger.info("Audio session configured for playback")
        } catch {
            logger.error("Failed to configure audio session: \(error.localizedDescription)")
        }
    }
}