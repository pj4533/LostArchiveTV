import Foundation
import SwiftUI
import OSLog

@MainActor
class CollectionConfigViewModel: ObservableObject {
    @Published var useDefaultCollections: Bool = true
    @Published var collections: [CollectionItem] = []
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    
    private let logger = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "CollectionConfig")
    private let databaseService: DatabaseService
    
    struct CollectionItem: Identifiable, Equatable {
        let id: String
        let name: String
        var isEnabled: Bool
        let isPreferred: Bool
        
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
            
            self.collections = allCollections.map { collection in
                CollectionItem(
                    id: collection.name,
                    name: collection.name,
                    isEnabled: enabledCollectionIds.contains(collection.name) || enabledCollectionIds.isEmpty,
                    isPreferred: collection.preferred
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
        
        Task {
            await loadCollections()
        }
    }
    
    func saveSettings() {
        let userDefaults = UserDefaults.standard
        userDefaults.set(useDefaultCollections, forKey: "UseDefaultCollections")
        
        let enabledCollectionIds = collections
            .filter { $0.isEnabled }
            .map { $0.id }
        
        userDefaults.set(enabledCollectionIds, forKey: "EnabledCollections")
    }
    
    func toggleDefaultCollections() {
        useDefaultCollections.toggle()
        saveSettings()
    }
    
    // User preferences methods moved to CollectionPreferences
}