import Foundation
import SwiftUI
import OSLog

@MainActor
class PresetSelectionViewModel: ObservableObject {
    @Published var presets: [FeedPreset] = []
    @Published var showingNewPresetAlert = false
    @Published var newPresetName = ""
    
    private let presetManager = PresetManager.shared
    private let logger = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "PresetSelection")
    
    init() {
        loadPresets()
    }
    
    func loadPresets() {
        presets = HomeFeedPreferences.getAllPresets()
    }
    
    func saveIdentifierToPreset(preset: FeedPreset, identifier: String, title: String, collection: String, fileCount: Int) -> (title: String, presetName: String, isDuplicate: Bool) {
        // Create the new saved identifier
        let newSavedIdentifier = UserSelectedIdentifier(
            id: identifier,
            identifier: identifier,
            title: title,
            collection: collection,
            fileCount: fileCount
        )
        
        // Check if the identifier is already in the preset
        let alreadyExists = preset.savedIdentifiers.contains(where: { $0.identifier == identifier })
        
        if !alreadyExists {
            // Add to the preset via the PresetManager
            PresetManager.shared.addIdentifier(newSavedIdentifier, toPresetWithId: preset.id)
            
            return (title: title, presetName: preset.name, isDuplicate: false)
        } else {
            return (title: title, presetName: preset.name, isDuplicate: true)
        }
    }
    
    func createNewPresetAndSaveIdentifier(name: String, identifier: String, title: String, collection: String, fileCount: Int) -> (title: String, presetName: String) {
        // Get enabled collections from current settings
        let enabledCollectionIds = HomeFeedPreferences.getEnabledCollections() ?? []
        
        // Create identifier
        let newSavedIdentifier = UserSelectedIdentifier(
            id: identifier,
            identifier: identifier,
            title: title,
            collection: collection,
            fileCount: fileCount
        )
        
        // Create new preset
        let newPreset = FeedPreset(
            name: name,
            enabledCollections: enabledCollectionIds,
            savedIdentifiers: [newSavedIdentifier],
            isSelected: false // Don't auto-select the new preset
        )
        
        HomeFeedPreferences.addPreset(newPreset)
        loadPresets()
        
        return (title: title, presetName: name)
    }
}