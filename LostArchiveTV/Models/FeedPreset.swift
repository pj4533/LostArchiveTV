import Foundation

struct FeedPreset: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var enabledCollections: [String]
    var savedIdentifiers: [UserSelectedIdentifier]
    var isSelected: Bool
    
    init(id: String = UUID().uuidString, 
         name: String, 
         enabledCollections: [String],
         savedIdentifiers: [UserSelectedIdentifier] = [],
         isSelected: Bool = false) {
        self.id = id
        self.name = name
        self.enabledCollections = enabledCollections
        self.savedIdentifiers = savedIdentifiers
        self.isSelected = isSelected
    }
    
    static func == (lhs: FeedPreset, rhs: FeedPreset) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Create a preset from current settings
    static func fromCurrentSettings(
        name: String, 
        enabledCollections: [String],
        savedIdentifiers: [UserSelectedIdentifier]
    ) -> FeedPreset {
        return FeedPreset(
            name: name,
            enabledCollections: enabledCollections,
            savedIdentifiers: savedIdentifiers,
            isSelected: true
        )
    }
}