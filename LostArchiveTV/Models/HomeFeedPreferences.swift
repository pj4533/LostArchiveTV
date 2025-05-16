import Foundation
import OSLog

// Simple utility class for managing home feed preferences
// Separate from HomeFeedSettingsViewModel to avoid async/await compilation issues
class HomeFeedPreferences {
    private static let logger = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "HomeFeedPreferences")
    private static let presetsKey = "FeedPresets"
    private static let useDefaultKey = "UseDefaultCollections"
    private static let enabledCollectionsKey = "EnabledCollections"
    private static let hasAddedALFPresetKey = "HasAddedALFPreset"
    
    // In-memory cache of last settings to detect changes
    private static var lastUseDefault: Bool = true
    private static var lastEnabledCollections: [String] = []
    private static var hasInitializedCache = false
    private static var initializingCache = false
    private static var presets: [FeedPreset] = []
    
    // Initialize the settings cache
    private static func initializeCache() {
        // Guard against recursive initialization
        if hasInitializedCache || initializingCache {
            return
        }
        
        initializingCache = true
        
        // Get basic settings first
        lastUseDefault = shouldUseDefaultCollections()
        
        // Load presets before getting collections to prevent recursion
        loadPresets()
        
        // Ensure migration happens during initialization
        migrateToPresetsIfNeeded()
        
        // Now get collections
        lastEnabledCollections = getEnabledCollections() ?? []
        
        initializingCache = false
        hasInitializedCache = true
    }
    
    // Get the last saved settings from our cache
    static func getLastSavedSettings() -> (useDefault: Bool, collections: [String]) {
        if !hasInitializedCache {
            initializeCache()
        }
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
        if userDefaults.object(forKey: useDefaultKey) == nil {
            return nil
        }
        
        let useDefault = userDefaults.bool(forKey: useDefaultKey)
        
        // If using default collections
        if useDefault {
            return nil
        }
        
        // If we have a selected preset and not initializing, use its collections
        if !initializingCache, let selectedPreset = getSelectedPresetWithoutInitializing() {
            return selectedPreset.enabledCollections
        }
        
        // Otherwise fall back to legacy settings
        return userDefaults.stringArray(forKey: enabledCollectionsKey)
    }
    
    // Check if we should use default collections
    static func shouldUseDefaultCollections() -> Bool {
        let userDefaults = UserDefaults.standard
        
        // If the setting isn't saved yet, default to true
        if userDefaults.object(forKey: useDefaultKey) == nil {
            logger.debug("UseDefaultCollections not set, defaulting to true")
            return true
        }
        
        let value = userDefaults.bool(forKey: useDefaultKey)
        logger.debug("Reading UseDefaultCollections from UserDefaults: \(value)")
        return value
    }
    
    // MARK: - Presets Management
    
    // Load all presets from UserDefaults
    static func loadPresets() {
        let userDefaults = UserDefaults.standard
        guard let data = userDefaults.data(forKey: presetsKey) else {
            presets = []
            return
        }
        
        do {
            presets = try JSONDecoder().decode([FeedPreset].self, from: data)
        } catch {
            logger.error("Failed to decode presets: \(error.localizedDescription)")
            presets = []
        }
    }
    
    // Save all presets to UserDefaults
    static func savePresets() {
        let userDefaults = UserDefaults.standard
        do {
            let data = try JSONEncoder().encode(presets)
            userDefaults.set(data, forKey: presetsKey)
        } catch {
            logger.error("Failed to encode presets: \(error.localizedDescription)")
        }
    }
    
    // Get all presets
    static func getAllPresets() -> [FeedPreset] {
        if !hasInitializedCache {
            initializeCache()
        }
        return presets
    }
    
    // Get the currently selected preset
    static func getSelectedPreset() -> FeedPreset? {
        if !hasInitializedCache {
            initializeCache()
        }
        return presets.first(where: { $0.isSelected })
    }
    
    // Get selected preset without triggering initialization
    private static func getSelectedPresetWithoutInitializing() -> FeedPreset? {
        return presets.first(where: { $0.isSelected })
    }
    
    // Select a preset
    static func selectPreset(withId id: String) {
        if !hasInitializedCache {
            initializeCache()
        }
        
        for i in 0..<presets.count {
            presets[i].isSelected = presets[i].id == id
        }
        savePresets()
        
        // Also update the lastEnabledCollections cache
        if let selectedPreset = getSelectedPresetWithoutInitializing() {
            lastEnabledCollections = selectedPreset.enabledCollections
        }
    }
    
    // Add a new preset
    static func addPreset(_ preset: FeedPreset) {
        if !hasInitializedCache {
            initializeCache()
        }
        
        // Deselect other presets if this one is selected
        if preset.isSelected {
            for i in 0..<presets.count {
                presets[i].isSelected = false
            }
        }
        presets.append(preset)
        savePresets()
    }
    
    // Update an existing preset
    static func updatePreset(_ preset: FeedPreset) {
        if !hasInitializedCache {
            initializeCache()
        }
        
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else {
            return
        }
        
        // If this preset is becoming selected, deselect others
        if preset.isSelected && !presets[index].isSelected {
            for i in 0..<presets.count {
                if i != index {
                    presets[i].isSelected = false
                }
            }
        }
        
        presets[index] = preset
        savePresets()
        
        // Update cache if this is the selected preset
        if preset.isSelected {
            lastEnabledCollections = preset.enabledCollections
        }
    }
    
    // Delete a preset
    static func deletePreset(withId id: String) {
        if !hasInitializedCache {
            initializeCache()
        }
        
        let wasSelected = presets.first(where: { $0.id == id })?.isSelected ?? false
        presets.removeAll(where: { $0.id == id })
        
        // If we deleted the selected preset, select the first one if available
        if wasSelected && !presets.isEmpty {
            presets[0].isSelected = true
            lastEnabledCollections = presets[0].enabledCollections
        }
        
        savePresets()
    }
    
    // Create initial preset from legacy settings if needed - should only be called from initializeCache
    private static func migrateToPresetsIfNeeded() {
        // Skip if we already have presets
        if !presets.isEmpty {
            return
        }
        
        // Skip if using default collections
        if shouldUseDefaultCollections() {
            return
        }
        
        // Get legacy enabled collections
        let legacyCollections = UserDefaults.standard.stringArray(forKey: enabledCollectionsKey) ?? []
        
        // Get saved identifiers from UserDefaults directly (don't use PresetManager yet since we're initializing it)
        var savedIdentifiers: [UserSelectedIdentifier] = []
        if let data = UserDefaults.standard.data(forKey: "UserSelectedIdentifiers") {
            do {
                savedIdentifiers = try JSONDecoder().decode([UserSelectedIdentifier].self, from: data)
            } catch {
                logger.error("Failed to decode legacy user-selected identifiers during migration: \(error.localizedDescription)")
            }
        }
        
        // Create a preset from legacy settings
        let currentPreset = FeedPreset(
            name: "Current",
            enabledCollections: legacyCollections,
            savedIdentifiers: savedIdentifiers,
            isSelected: true
        )
        
        presets = [currentPreset]
        savePresets()
        
        logger.debug("Migrated legacy settings to 'Current' preset")
    }
    
    // Public migration function - call this when app starts
    static func migrateToPresets() {
        if !hasInitializedCache {
            initializeCache()
        }
        
        // Add the ALF preset if it doesn't already exist
        addALFPresetIfNeeded()
    }
    
    // Adds ALF preset if it hasn't been added before
    private static func addALFPresetIfNeeded() {
        let userDefaults = UserDefaults.standard
        
        // If we've already added the ALF preset, do nothing
        if userDefaults.bool(forKey: hasAddedALFPresetKey) {
            return
        }
        
        // Create the ALF preset with the specific identifier
        let alfIdentifier = UserSelectedIdentifier(
            id: "ALF-The-Complete-Series",
            identifier: "ALF-The-Complete-Series",
            title: "ALF - The Complete Series",
            collection: "avgeeks",
            fileCount: 1
        )
        
        // Create the preset (not selected by default)
        let alfPreset = FeedPreset(
            name: "ALF",
            enabledCollections: [],
            savedIdentifiers: [alfIdentifier],
            isSelected: false
        )
        
        // Add the preset to our list
        addPreset(alfPreset)
        
        // Mark that we've added the ALF preset
        userDefaults.set(true, forKey: hasAddedALFPresetKey)
        
        logger.debug("Added ALF preset to user's presets")
    }
}
