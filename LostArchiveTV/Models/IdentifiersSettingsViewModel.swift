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
    private let presetManager = PresetManager.shared
    
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
    
    // Default init for currently selected preset's identifiers
    init() {
        loadIdentifiers()
    }
    
    // Init with a specific preset reference
    init(preset: FeedPreset) {
        self.preset = preset
        self.identifiers = preset.savedIdentifiers
    }
    
    func loadIdentifiers() {
        if let preset = preset {
            // If we have a specific preset, load its identifiers
            self.identifiers = preset.savedIdentifiers
        } else {
            // Otherwise load from the currently selected preset
            self.identifiers = presetManager.getIdentifiers()
        }
    }
    
    func removeIdentifier(_ id: String) {
        // If we're viewing a specific preset, update that preset
        if let preset = preset {
            var updatedPreset = preset
            updatedPreset.savedIdentifiers.removeAll(where: { $0.id == id })
            HomeFeedPreferences.updatePreset(updatedPreset)
            // Update our local reference
            self.preset = updatedPreset
            self.identifiers = updatedPreset.savedIdentifiers
        } else {
            // Otherwise remove from the currently selected preset
            presetManager.removeIdentifier(withId: id)
            // Reload identifiers from the current preset
            self.identifiers = presetManager.getIdentifiers()
        }
    }
}