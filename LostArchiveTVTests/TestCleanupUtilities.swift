import Foundation
@testable import LATV

/// Utilities for cleaning up test state between tests
enum TestCleanupUtilities {
    
    /// Removes all notification observers for a specific notification name
    /// This helps isolate tests that use notifications
    static func removeAllObservers(for notificationName: Notification.Name) {
        // Remove all observers for this specific notification
        NotificationCenter.default.removeObserver(notificationName)
    }
    
    /// Clears all presets and waits for any resulting notifications
    static func clearAllPresets() async {
        let allPresets = HomeFeedPreferences.getAllPresets()
        for preset in allPresets {
            HomeFeedPreferences.deletePreset(withId: preset.id)
        }
        // Wait for deletion notifications to settle
        try? await Task.sleep(for: .milliseconds(100))
    }
    
    /// Creates a clean test environment with no presets
    static func setupCleanEnvironment() async {
        await clearAllPresets()
        // Additional cleanup can be added here as needed
    }
}