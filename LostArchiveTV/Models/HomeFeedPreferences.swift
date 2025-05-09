import Foundation
import OSLog

// Simple utility class for managing home feed preferences
// Separate from HomeFeedSettingsViewModel to avoid async/await compilation issues
class HomeFeedPreferences {
    // In-memory cache of last settings to detect changes
    private static var lastUseDefault: Bool = true
    private static var lastEnabledCollections: [String] = []
    private static var hasInitializedCache = false
    
    // Initialize the settings cache
    private static func initializeCache() {
        if !hasInitializedCache {
            lastUseDefault = shouldUseDefaultCollections()
            lastEnabledCollections = getEnabledCollections() ?? []
            hasInitializedCache = true
        }
    }
    
    // Get the last saved settings from our cache
    static func getLastSavedSettings() -> (useDefault: Bool, collections: [String]) {
        initializeCache()
        return (useDefault: lastUseDefault, collections: lastEnabledCollections)
    }
    
    // Update the cached settings
    static func updateLastSavedSettings(useDefault: Bool, collections: [String]) {
        lastUseDefault = useDefault
        lastEnabledCollections = collections
        hasInitializedCache = true
    }
    
    // Check if user has custom collection settings
    static func getEnabledCollections() -> [String]? {
        let userDefaults = UserDefaults.standard
        
        // If the setting isn't saved yet
        if userDefaults.object(forKey: "UseDefaultCollections") == nil {
            return nil
        }
        
        let useDefault = userDefaults.bool(forKey: "UseDefaultCollections")
        
        // If using default collections
        if useDefault {
            return nil
        }
        
        return userDefaults.stringArray(forKey: "EnabledCollections")
    }
    
    // Check if we should use default collections
    static func shouldUseDefaultCollections() -> Bool {
        let userDefaults = UserDefaults.standard
        
        // If the setting isn't saved yet, default to true
        if userDefaults.object(forKey: "UseDefaultCollections") == nil {
            return true
        }
        
        return userDefaults.bool(forKey: "UseDefaultCollections")
    }
}