import Foundation
import SwiftUI
import OSLog
import Combine

@MainActor
class HomeFeedSettingsViewModel: ObservableObject {
    @Published var useDefaultCollections: Bool = true
    @Published var collections: [CollectionItem] = []
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var presets: [FeedPreset] = []
    @Published var showingNewPresetAlert: Bool = false
    @Published var newPresetName: String = ""
    @Published var showingEditPresetView: Bool = false
    @Published var selectedPresetForEdit: FeedPreset?
    
    private let logger = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "HomeFeedSettings")
    private let databaseService: DatabaseService
    private var cancellables = Set<AnyCancellable>()
    
    struct CollectionItem: Identifiable, Equatable {
        let id: String
        let name: String
        var isEnabled: Bool
        let isPreferred: Bool
        var isExcluded: Bool
        
        static func == (lhs: CollectionItem, rhs: CollectionItem) -> Bool {
            return lhs.id == rhs.id
        }
    }
    
    init(databaseService: DatabaseService) {
        self.databaseService = databaseService
        loadSettings()
        subscribeToPresetChanges()
    }
    
    var filteredCollections: [CollectionItem] {
        if searchText.isEmpty {
            return collections
        } else {
            return collections.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
    }
    
    var selectedPreset: FeedPreset? {
        return presets.first(where: { $0.isSelected })
    }
    
    // MARK: - Collection Loading and Management
    
    func loadCollections() async {
        isLoading = true
        do {
            let allCollections = try await databaseService.getAllCollections()
            let enabledCollectionIds = getEnabledCollectionIds()
            
            // Only default all collections to enabled if this is the first time loading
            // (i.e., no user preference has been saved yet)
            let hasUserMadeSelection = UserDefaults.standard.object(forKey: "EnabledCollections") != nil
            let defaultToEnabled = !hasUserMadeSelection
            
            self.collections = allCollections.map { collection in
                CollectionItem(
                    id: collection.name,
                    name: collection.name,
                    isEnabled: defaultToEnabled || enabledCollectionIds.contains(collection.name),
                    isPreferred: collection.preferred,
                    isExcluded: collection.excluded
                )
            }
            
            // Sort collections alphabetically
            self.collections.sort { $0.name < $1.name }
            
        } catch {
            logger.error("Error loading collections: \(error.localizedDescription)")
        }
        isLoading = false
    }
    
    func toggleCollection(_ id: String) {
        if let index = collections.firstIndex(where: { $0.id == id }) {
            collections[index].isEnabled.toggle()
            saveSettings()
        }
    }
    
    func selectAll() {
        for index in collections.indices {
            collections[index].isEnabled = true
        }
        saveSettings()
    }
    
    func deselectAll() {
        for index in collections.indices {
            collections[index].isEnabled = false
        }
        saveSettings()
    }
    
    // MARK: - Settings Loading and Saving
    
    func loadSettings() {
        let userDefaults = UserDefaults.standard
        
        // Ensure migration happens first
        HomeFeedPreferences.migrateToPresets()
        
        // If there's no saved preference, default to true
        if userDefaults.object(forKey: "UseDefaultCollections") == nil {
            useDefaultCollections = true
            userDefaults.set(true, forKey: "UseDefaultCollections")
        } else {
            useDefaultCollections = userDefaults.bool(forKey: "UseDefaultCollections")
        }
        
        // Load presets
        presets = HomeFeedPreferences.getAllPresets()
        
        // Load collections only once at init
        if collections.isEmpty {
            Task {
                await loadCollections()
                
                // After loading collections, sync them with the selected preset
                syncCollectionsWithSelectedPreset()
            }
        }
    }
    
    func saveSettings() {
        let userDefaults = UserDefaults.standard
        userDefaults.set(useDefaultCollections, forKey: "UseDefaultCollections")
        
        if let selectedPreset = selectedPreset {
            // If we have a selected preset, update its collections
            let enabledCollectionIds = collections
                .filter { $0.isEnabled }
                .map { $0.id }
            
            var updatedPreset = selectedPreset
            updatedPreset.enabledCollections = enabledCollectionIds
            HomeFeedPreferences.updatePreset(updatedPreset)
        } else {
            // Legacy fallback if no preset is selected
            let enabledCollectionIds = collections
                .filter { $0.isEnabled }
                .map { $0.id }
            
            userDefaults.set(enabledCollectionIds, forKey: "EnabledCollections")
        }
        
        // Update the in-memory cache
        HomeFeedPreferences.updateLastSavedSettings(
            useDefault: useDefaultCollections,
            collections: getEnabledCollectionIds()
        )
        
        // Reload presets
        presets = HomeFeedPreferences.getAllPresets()
        
        // Automatically reload identifiers when settings change
        Task {
            await reloadIdentifiers()
        }
    }
    
    private func getEnabledCollectionIds() -> [String] {
        if let selectedPreset = selectedPreset {
            return selectedPreset.enabledCollections
        } else {
            return UserDefaults.standard.stringArray(forKey: "EnabledCollections") ?? []
        }
    }
    
    func toggleDefaultCollections() {
        useDefaultCollections.toggle()
        
        // First, explicitly save the UseDefaultCollections setting
        UserDefaults.standard.set(useDefaultCollections, forKey: "UseDefaultCollections")
        
        // Then save the rest of the settings
        saveSettings()
        
        // Log the change for debugging
        logger.debug("Toggled UseDefaultCollections to \(self.useDefaultCollections)")
    }
    
    // Reload identifiers - called when collection settings change
    func reloadIdentifiers() async {
        // Send collectionsUpdated event through PresetManager
        logger.debug("Reloading identifiers after settings change")
        
        if let selectedPreset = selectedPreset {
            let enabledCollectionIds = collections
                .filter { $0.isEnabled }
                .map { $0.id }
            
            PresetManager.shared.presetEvents.send(.collectionsUpdated(enabledCollectionIds, presetId: selectedPreset.id))
        }
    }
    
    // MARK: - Preset Management
    
    func loadPresets() {
        presets = HomeFeedPreferences.getAllPresets()
    }
    
    @MainActor
    func syncCollectionsWithSelectedPreset() {
        guard let selectedPreset = selectedPreset else { return }
        
        for i in 0..<collections.count {
            collections[i].isEnabled = selectedPreset.enabledCollections.contains(collections[i].id)
        }
    }
    
    func selectPreset(withId id: String) {
        // Find the preset and use PresetManager to select it
        if let preset = presets.first(where: { $0.id == id }) {
            PresetManager.shared.setSelectedPreset(preset)
            
            // Set useDefaultCollections to false when selecting a preset
            useDefaultCollections = false
            UserDefaults.standard.set(false, forKey: "UseDefaultCollections")
            
            // The UI will update through the Combine subscription
        }
    }
    
    func createNewPreset(name: String) {
        // Get currently enabled collections
        let enabledCollectionIds = collections
            .filter { $0.isEnabled }
            .map { $0.id }
        
        // Get saved identifiers from the current preset
        let savedIdentifiers = PresetManager.shared.getIdentifiers()
        
        // Create a new preset
        let newPreset = FeedPreset(
            name: name,
            enabledCollections: enabledCollectionIds,
            savedIdentifiers: savedIdentifiers,
            isSelected: true // Automatically select the new preset
        )
        
        HomeFeedPreferences.addPreset(newPreset)
        loadPresets()
        
        // Notify of changes
        saveSettings()
    }
    
    func updatePreset(_ preset: FeedPreset) {
        HomeFeedPreferences.updatePreset(preset)
        loadPresets()
        
        // Update the collections view if this is the selected preset
        if preset.isSelected {
            syncCollectionsWithSelectedPreset()
        }
        
        // Notify of changes
        saveSettings()
    }
    
    func deletePreset(withId id: String) {
        HomeFeedPreferences.deletePreset(withId: id)
        loadPresets()
        
        // If we now have a different selected preset, update the collections view
        syncCollectionsWithSelectedPreset()
        
        // Notify of changes
        saveSettings()
    }
    
    func getCurrentPresetName() -> String {
        return selectedPreset?.name ?? "Default"
    }
    
    // MARK: - Combine Subscriptions
    
    private func subscribeToPresetChanges() {
        // Subscribe to currentPreset changes from PresetManager
        PresetManager.shared.$currentPreset
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newPreset in
                guard let self = self else { return }
                
                // Update presets array to reflect the new selection
                self.presets = HomeFeedPreferences.getAllPresets()
                
                // Sync collections with the new preset
                if newPreset != nil {
                    self.syncCollectionsWithSelectedPreset()
                }
                
                // Update useDefaultCollections state based on preset
                if newPreset != nil {
                    self.useDefaultCollections = false
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to preset events for specific updates
        PresetManager.shared.presetEvents
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                
                switch event {
                case .presetChanged:
                    // Reload presets when a preset is changed
                    self.presets = HomeFeedPreferences.getAllPresets()
                    self.syncCollectionsWithSelectedPreset()
                    
                case .collectionsUpdated(let collections, let presetId):
                    // If the update is for our selected preset, sync the UI
                    if let selectedPreset = self.selectedPreset, selectedPreset.id == presetId {
                        self.syncCollectionsWithSelectedPreset()
                    }
                    
                default:
                    break // Ignore identifier events in this view model
                }
            }
            .store(in: &cancellables)
    }
}