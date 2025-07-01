//
//  PresetManager.swift
//  LostArchiveTV
//
//  Created by Claude on 5/14/25.
//

import Foundation
import OSLog
import SwiftUI
import Combine

enum PresetEvent: Equatable {
    case identifierAdded(UserSelectedIdentifier, presetId: String)
    case identifierRemoved(id: String, presetId: String)
    case presetChanged(FeedPreset)
    case collectionsUpdated([String], presetId: String)
}

/// Manager for presets and their identifiers, providing a single interface for all preset operations
@MainActor
class PresetManager: ObservableObject {
    static let shared = PresetManager()
    
    private let logger = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "PresetManager")
    
    @Published private(set) var currentPreset: FeedPreset?
    @Published private(set) var identifiers: [UserSelectedIdentifier] = []
    let presetEvents = PassthroughSubject<PresetEvent, Never>()
    
    private init() {
        // Initialize current preset from selected preset
        self.currentPreset = HomeFeedPreferences.getSelectedPreset()
        // Load identifiers for current preset
        self.identifiers = loadIdentifiers()
    }
    
    private func loadIdentifiers() -> [UserSelectedIdentifier] {
        guard let preset = currentPreset else {
            return []
        }
        return preset.savedIdentifiers
    }
    
    // MARK: - Preset Selection
    
    /// Sets the selected preset and updates all related state
    /// - Parameter preset: The preset to select
    func setSelectedPreset(_ preset: FeedPreset) {
        // Store the preset in UserDefaults
        HomeFeedPreferences.selectPreset(withId: preset.id)
        
        // Update currentPreset
        currentPreset = preset
        
        // Send presetChanged event
        presetEvents.send(.presetChanged(preset))
        
        // Update identifiers array
        identifiers = loadIdentifiers()
    }
    
    // MARK: - Selected Preset Access
    
    /// Gets the currently selected preset
    /// - Returns: The currently selected preset, or nil if none is selected
    func getSelectedPreset() -> FeedPreset? {
        let preset = HomeFeedPreferences.getSelectedPreset()
        // Update currentPreset if it's different
        if preset?.id != currentPreset?.id {
            currentPreset = preset
            identifiers = loadIdentifiers()
        }
        return preset
    }
    
    /// Checks if an identifier is saved in the currently selected preset
    /// - Parameter identifier: The identifier string to check
    /// - Returns: True if the identifier exists in the selected preset
    func contains(identifier: String) -> Bool {
        guard let preset = getSelectedPreset() else {
            return false
        }
        
        return preset.savedIdentifiers.contains(where: { $0.identifier == identifier })
    }
    
    /// Gets all identifiers from the currently selected preset
    /// - Returns: Array of UserSelectedIdentifiers from the selected preset, or empty array if no preset
    func getIdentifiers() -> [UserSelectedIdentifier] {
        guard let preset = getSelectedPreset() else {
            return []
        }
        
        return preset.savedIdentifiers
    }
    
    /// Gets all identifiers from the currently selected preset as ArchiveIdentifiers
    /// - Returns: Array of ArchiveIdentifiers from the selected preset, or empty array if no preset
    func getArchiveIdentifiers() -> [ArchiveIdentifier] {
        guard let preset = getSelectedPreset() else {
            return []
        }
        
        return preset.savedIdentifiers.map { $0.archiveIdentifier }
    }
    
    // MARK: - Identifier Management
    
    /// Adds an identifier to the currently selected preset
    /// - Parameter newIdentifier: The identifier to add
    /// - Returns: True if added successfully, false otherwise
    @discardableResult
    func addIdentifier(_ newIdentifier: UserSelectedIdentifier) -> Bool {
        guard let preset = getSelectedPreset() else {
            logger.error("Cannot add identifier - no preset selected")
            return false
        }
        
        var updatedPreset = preset
        
        // Don't add duplicates
        guard !updatedPreset.savedIdentifiers.contains(where: { $0.identifier == newIdentifier.identifier }) else {
            return false
        }
        
        updatedPreset.savedIdentifiers.append(newIdentifier)
        HomeFeedPreferences.updatePreset(updatedPreset)
        
        // Update current preset if this is the selected one
        if updatedPreset.isSelected {
            currentPreset = updatedPreset
        }
        
        // Send Combine event and update published identifiers
        presetEvents.send(.identifierAdded(newIdentifier, presetId: preset.id))
        identifiers = loadIdentifiers()
        
        return true
    }
    
    /// Removes an identifier from the currently selected preset
    /// - Parameter id: The id of the identifier to remove
    /// - Returns: True if removed successfully, false otherwise
    @discardableResult
    func removeIdentifier(withId id: String) -> Bool {
        guard let preset = getSelectedPreset() else {
            logger.error("Cannot remove identifier - no preset selected")
            return false
        }
        
        var updatedPreset = preset
        
        // Check if the identifier exists before trying to remove
        guard updatedPreset.savedIdentifiers.contains(where: { $0.id == id }) else {
            return false
        }
        
        updatedPreset.savedIdentifiers.removeAll(where: { $0.id == id })
        HomeFeedPreferences.updatePreset(updatedPreset)
        
        // Update current preset if this is the selected one
        if updatedPreset.isSelected {
            currentPreset = updatedPreset
        }
        
        // Send Combine event and update published identifiers
        presetEvents.send(.identifierRemoved(id: id, presetId: preset.id))
        identifiers = loadIdentifiers()
        
        return true
    }
    
    // MARK: - Multi-Preset Operations
    
    /// Adds an identifier to a specific preset
    /// - Parameters:
    ///   - identifier: The identifier to add
    ///   - presetId: The ID of the preset to add the identifier to
    /// - Returns: True if added successfully, false otherwise
    @discardableResult
    func addIdentifier(_ identifier: UserSelectedIdentifier, toPresetWithId presetId: String) -> Bool {
        let allPresets = HomeFeedPreferences.getAllPresets()
        guard let presetIndex = allPresets.firstIndex(where: { $0.id == presetId }) else {
            logger.error("Cannot add identifier - preset with ID \(presetId) not found")
            return false
        }
        
        var updatedPreset = allPresets[presetIndex]
        
        // Don't add duplicates
        guard !updatedPreset.savedIdentifiers.contains(where: { $0.identifier == identifier.identifier }) else {
            return false
        }
        
        updatedPreset.savedIdentifiers.append(identifier)
        HomeFeedPreferences.updatePreset(updatedPreset)
        
        // Update current preset if we're adding to the selected preset
        if let selected = currentPreset, selected.id == presetId {
            currentPreset = updatedPreset
            identifiers = loadIdentifiers()
        }
        
        // Send Combine event
        presetEvents.send(.identifierAdded(identifier, presetId: presetId))
        
        return true
    }
    
    /// Gets all identifiers from a specific preset
    /// - Parameter presetId: The ID of the preset to get identifiers from
    /// - Returns: Array of UserSelectedIdentifiers from the preset, or empty array if preset not found
    func getIdentifiers(fromPresetWithId presetId: String) -> [UserSelectedIdentifier] {
        let allPresets = HomeFeedPreferences.getAllPresets()
        guard let preset = allPresets.first(where: { $0.id == presetId }) else {
            return []
        }
        
        return preset.savedIdentifiers
    }
    
    /// Checks if an identifier exists in a specific preset
    /// - Parameters:
    ///   - identifier: The identifier string to check
    ///   - presetId: The ID of the preset to check
    /// - Returns: True if the identifier exists in the preset
    func presetContains(identifier: String, inPresetWithId presetId: String) -> Bool {
        let allPresets = HomeFeedPreferences.getAllPresets()
        guard let preset = allPresets.first(where: { $0.id == presetId }) else {
            return false
        }
        
        return preset.savedIdentifiers.contains(where: { $0.identifier == identifier })
    }
    
    /// Gets presets that contain a specific identifier
    /// - Parameter identifier: The identifier string to check
    /// - Returns: Array of presets that contain the identifier
    func getPresetsThatContain(identifier: String) -> [FeedPreset] {
        let allPresets = HomeFeedPreferences.getAllPresets()
        return allPresets.filter { preset in
            preset.savedIdentifiers.contains(where: { $0.identifier == identifier })
        }
    }
    
    // MARK: - Legacy Compatibility
    
    /// For backward compatibility during migration - refreshes the selected preset
    /// This should only be called during migration or when we need to force consistency
    func refreshSelectedPreset() {
        if let selectedPreset = getSelectedPreset() {
            HomeFeedPreferences.updatePreset(selectedPreset)
            currentPreset = selectedPreset
            identifiers = loadIdentifiers()
        }
    }
}