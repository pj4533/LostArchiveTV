import Foundation
import SwiftUI
import OSLog

@MainActor
class HomeFeedSettingsViewModel: ObservableObject {
    @Published var useDefaultCollections: Bool = true
    @Published var collections: [CollectionItem] = []
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    
    private let logger = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "HomeFeedSettings")
    private let databaseService: DatabaseService
    
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
    }
    
    var filteredCollections: [CollectionItem] {
        if searchText.isEmpty {
            return collections
        } else {
            return collections.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
    }
    
    func loadCollections() async {
        isLoading = true
        do {
            let allCollections = try await databaseService.getAllCollections()
            let userDefaults = UserDefaults.standard
            let enabledCollectionIds = userDefaults.stringArray(forKey: "EnabledCollections") ?? []
            
            // Only default all collections to enabled if this is the first time loading
            // (i.e., no user preference has been saved yet)
            let hasUserMadeSelection = userDefaults.object(forKey: "EnabledCollections") != nil
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
    
    func loadSettings() {
        let userDefaults = UserDefaults.standard
        
        // If there's no saved preference, default to true
        if userDefaults.object(forKey: "UseDefaultCollections") == nil {
            useDefaultCollections = true
            userDefaults.set(true, forKey: "UseDefaultCollections")
        } else {
            useDefaultCollections = userDefaults.bool(forKey: "UseDefaultCollections")
        }
        
        // Load collections only once at init
        if collections.isEmpty {
            Task {
                await loadCollections()
            }
        }
    }
    
    func saveSettings() {
        let userDefaults = UserDefaults.standard
        userDefaults.set(useDefaultCollections, forKey: "UseDefaultCollections")
        
        let enabledCollectionIds = collections
            .filter { $0.isEnabled }
            .map { $0.id }
        
        userDefaults.set(enabledCollectionIds, forKey: "EnabledCollections")
        
        // Automatically reload identifiers when settings change
        Task {
            await reloadIdentifiers()
        }
    }
    
    func toggleDefaultCollections() {
        useDefaultCollections.toggle()
        saveSettings()
    }
    
    // Reload identifiers - called when collection settings change
    func reloadIdentifiers() async {
        // Notify that settings have been changed and identifiers should be reloaded
        logger.debug("Reloading identifiers after settings change")
        NotificationCenter.default.post(name: Notification.Name("ReloadIdentifiers"), object: nil)
    }
}