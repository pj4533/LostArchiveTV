import Foundation
import OSLog

// Simple utility class for managing collection preferences
// Separate from CollectionConfigViewModel to avoid async/await compilation issues
class CollectionPreferences {
    
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