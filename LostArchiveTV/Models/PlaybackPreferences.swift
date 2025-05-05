import Foundation

struct PlaybackPreferences {
    // Key for storing the setting
    private static let startAtBeginningKey = "AlwaysStartVideosAtBeginning"
    
    // Check if we should always start videos at the beginning
    static var alwaysStartAtBeginning: Bool {
        get {
            return UserDefaults.standard.bool(forKey: startAtBeginningKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: startAtBeginningKey)
        }
    }
}