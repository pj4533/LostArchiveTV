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

            // Log current state for debugging
            let currentState = describeCurrentState()
            logger.debug("📊 AUDIO_TRIM_START: Current audio session before trim setup: \(currentState)")

            // Check for any active players that might be using the session
            let otherAudioActive = audioSession.isOtherAudioPlaying
            logger.debug("📊 AUDIO_TRIM_CHECK: Other audio active before deactivation: \(otherAudioActive)")

            // First try to deactivate any existing session
            do {
                logger.debug("📊 AUDIO_TRIM_DEACTIVATE: Attempting to deactivate existing session")
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                logger.debug("📊 AUDIO_TRIM_DEACTIVATE: Successfully deactivated existing session")
            } catch {
                logger.error("📊 AUDIO_TRIM_DEACTIVATE: Failed to deactivate session: \(error.localizedDescription)")
            }

            // Set new category and activate
            logger.debug("📊 AUDIO_TRIM_CONFIG: Setting category to playback with moviePlayback mode")
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: .duckOthers)

            logger.debug("📊 AUDIO_TRIM_ACTIVATE: Attempting to activate trim audio session")
            try audioSession.setActive(true)

            // Log final configuration
            let finalState = describeCurrentState()
            logger.debug("📊 AUDIO_TRIM_COMPLETE: Trim audio session successfully configured: \(finalState)")
        } catch {
            logger.error("📊 AUDIO_TRIM_ERROR: Failed to set up trim view audio session: \(error.localizedDescription)")
        }
    }
    
    /// Deactivate audio session when finished
    func deactivate() {
        do {
            // Get current state for debugging
            let audioSession = AVAudioSession.sharedInstance()
            let currentState = describeCurrentState()
            logger.debug("📊 AUDIO_DEACTIVATE_START: Current audio session before deactivation: \(currentState)")

            // Check if there's any other audio playing
            let otherAudioActive = audioSession.isOtherAudioPlaying
            logger.debug("📊 AUDIO_DEACTIVATE_CHECK: Other audio active before deactivation: \(otherAudioActive)")

            // Deactivate our audio session
            logger.debug("📊 AUDIO_DEACTIVATE: Attempting to deactivate session with notification")
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)

            // Get state after deactivation
            let afterState = describeCurrentState()
            logger.debug("📊 AUDIO_DEACTIVATE_COMPLETE: Successfully deactivated audio session (before: \(currentState), after: \(afterState))")
        } catch {
            logger.error("📊 AUDIO_DEACTIVATE_ERROR: Failed to deactivate audio session: \(error.localizedDescription), current state: \(self.describeCurrentState())")
        }
    }
    
    /// Configure audio session for general video playback
    func configureForPlayback() {
        do {
            let audioSession = AVAudioSession.sharedInstance()

            // Log current state in detail
            let currentState = describeCurrentState()
            logger.debug("📊 AUDIO_PLAY_START: Current audio session before playback setup: \(currentState)")

            // Check for any active players that might be using the session
            let otherAudioActive = audioSession.isOtherAudioPlaying
            logger.debug("📊 AUDIO_PLAY_CHECK: Other audio active before configuration: \(otherAudioActive)")

            // First try to deactivate any existing session
            do {
                logger.debug("📊 AUDIO_PLAY_DEACTIVATE: Attempting to deactivate existing session")
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                logger.debug("📊 AUDIO_PLAY_DEACTIVATE: Successfully deactivated existing session")
            } catch {
                logger.error("📊 AUDIO_PLAY_DEACTIVATE: Failed to deactivate session: \(error.localizedDescription)")
            }

            // Set new category and activate
            logger.debug("📊 AUDIO_PLAY_CONFIG: Setting category to playback with moviePlayback mode")
            try audioSession.setCategory(.playback, mode: .moviePlayback)

            logger.debug("📊 AUDIO_PLAY_ACTIVATE: Attempting to activate playback audio session")
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            // Log final configuration
            let finalState = describeCurrentState()
            logger.info("📊 AUDIO_PLAY_COMPLETE: Playback audio session successfully configured: \(finalState)")
        } catch {
            logger.error("📊 AUDIO_PLAY_ERROR: Failed to configure playback audio session: \(error.localizedDescription)")
        }
    }
    
    /// Returns a string describing the current audio session state for debugging
    func describeCurrentState() -> String {
        let audioSession = AVAudioSession.sharedInstance()
        let category = audioSession.category.rawValue
        let mode = audioSession.mode.rawValue
        let isOtherPlaying = audioSession.isOtherAudioPlaying
        let isActive = audioSession.isOtherAudioPlaying ? "Yes" : "No"

        // Get additional detailed information
        let outputVolume = audioSession.outputVolume
        let inputAvailable = audioSession.isInputAvailable
        let sampleRate = audioSession.sampleRate
        let preferredSampleRate = audioSession.preferredSampleRate
        let outputLatency = audioSession.outputLatency

        return """
        Category=\(category), Mode=\(mode), \
        OtherPlaying=\(isOtherPlaying), Active=\(isActive), \
        OutputVolume=\(outputVolume), InputAvailable=\(inputAvailable), \
        SampleRate=\(sampleRate), PreferredRate=\(preferredSampleRate), \
        OutputLatency=\(outputLatency)
        """
    }
}