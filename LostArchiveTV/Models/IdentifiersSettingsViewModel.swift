//
//  IdentifiersSettingsViewModel.swift
//  LostArchiveTV
//
//  Created by Claude on 5/9/25.
//

import Foundation
import SwiftUI
import OSLog

@MainActor
class IdentifiersSettingsViewModel: ObservableObject {
    @Published var identifiers: [UserSelectedIdentifier] = []
    @Published var searchText: String = ""
    
    private let logger = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "IdentifiersSettings")
    private let manager = UserSelectedIdentifiersManager.shared
    
    // Reference to the preset being viewed
    var preset: FeedPreset?
    
    var filteredIdentifiers: [UserSelectedIdentifier] {
        if searchText.isEmpty {
            return identifiers
        } else {
            return identifiers.filter { 
                $0.title.lowercased().contains(searchText.lowercased()) ||
                $0.identifier.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    // Default init for manager identifiers
    init() {
        loadIdentifiers()
    }
    
    // Init with a preset reference
    init(preset: FeedPreset) {
        self.preset = preset
        self.identifiers = preset.savedIdentifiers
    }
    
    func loadIdentifiers() {
        if let preset = preset {
            // If we have a preset, load its identifiers
            self.identifiers = preset.savedIdentifiers
        } else {
            // Otherwise load from the manager
            self.identifiers = manager.identifiers
        }
    }
    
    func removeIdentifier(_ id: String) {
        // Remove from the current list
        identifiers.removeAll(where: { $0.id == id })
        
        // If we're viewing a preset, update the preset with the modified list
        if let preset = preset {
            var updatedPreset = preset
            updatedPreset.savedIdentifiers = identifiers
            HomeFeedPreferences.updatePreset(updatedPreset)
            // Update our local reference
            self.preset = updatedPreset
        } else {
            // Otherwise remove from manager
            manager.removeIdentifier(withId: id)
        }
        
        // Reload to get the latest state
        loadIdentifiers()
    }
}