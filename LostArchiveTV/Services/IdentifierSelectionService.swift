//
//  IdentifierSelectionService.swift
//  LostArchiveTV
//
//  Created by Claude on 5/11/25.
//

import Foundation
import OSLog

/// Service responsible for selecting identifiers based on user preferences
class IdentifierSelectionService {
    // Singleton instance
    static let shared = IdentifierSelectionService()

    private let logger = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "IdentifierSelection")
    private let dbService = DatabaseService.shared

    // UserDefaults keys for persisting the selection state
    private let availablePoolKey = "IdentifierSelectionAvailablePool"
    private let usedPoolKey = "IdentifierSelectionUsedPool"
    private let lastPreferencesHashKey = "IdentifierSelectionLastPreferencesHash"

    // In-memory cache of the selection pools
    private var availableSelectionPool: [String] = []
    private var usedSelectionPool: [String] = []
    private var lastPreferencesHash: String = ""

    // Private initializer for singleton
    private init() {
        loadSelectionState()
    }

    // MARK: - Selection State Management

    /// Loads the selection state from persistent storage
    private func loadSelectionState() {
        let userDefaults = UserDefaults.standard

        if let availablePool = userDefaults.stringArray(forKey: availablePoolKey) {
            availableSelectionPool = availablePool
        }

        if let usedPool = userDefaults.stringArray(forKey: usedPoolKey) {
            usedSelectionPool = usedPool
        }

        lastPreferencesHash = userDefaults.string(forKey: lastPreferencesHashKey) ?? ""

        logger.debug("Loaded selection state: \(self.availableSelectionPool.count) available, \(self.usedSelectionPool.count) used")
    }

    /// Saves the current selection state to persistent storage
    private func saveSelectionState() {
        let userDefaults = UserDefaults.standard

        userDefaults.set(availableSelectionPool, forKey: availablePoolKey)
        userDefaults.set(usedSelectionPool, forKey: usedPoolKey)
        userDefaults.set(lastPreferencesHash, forKey: lastPreferencesHashKey)

        logger.debug("Saved selection state: \(self.availableSelectionPool.count) available, \(self.usedSelectionPool.count) used")
    }

    /// Generates a hash of the current user preferences to detect changes
    private func generatePreferencesHash() -> String {
        // Check if the key exists in UserDefaults
        let userDefaults = UserDefaults.standard
        let keyExists = userDefaults.object(forKey: "UseDefaultCollections") != nil
        
        // If key doesn't exist or is true, use default preset (handle fresh installs correctly)
        let useDefault = !keyExists || userDefaults.bool(forKey: "UseDefaultCollections")
        
        // Get the relevant preset
        let preset: FeedPreset?
        if useDefault {
            preset = DefaultPreset.getPreset()
        } else {
            preset = HomeFeedPreferences.getSelectedPreset()
        }
        
        guard let activePreset = preset else {
            return "no-preset"
        }
        
        // Create a deterministic string representing all preset data
        let collectionsString = activePreset.enabledCollections.sorted().joined(separator: ",")
        let identifiersString = activePreset.savedIdentifiers.map { $0.identifier }.sorted().joined(separator: ",")
        
        // Also include the preset ID and a flag for default/custom mode
        return "\(useDefault ? "default" : "custom")|\(activePreset.id)|\(collectionsString)|\(identifiersString)"
    }

    /// Initializes or resets the selection pools based on current user preferences
    private func initializeSelectionPools() {
        // Check if the key exists in UserDefaults
        let userDefaults = UserDefaults.standard
        let keyExists = userDefaults.object(forKey: "UseDefaultCollections") != nil
        
        // If key doesn't exist or is true, use default preset (handle fresh installs correctly)
        let useDefault = !keyExists || userDefaults.bool(forKey: "UseDefaultCollections")
        
        // Determine which preset to use
        let preset: FeedPreset
        if useDefault {
            preset = DefaultPreset.getPreset()
            if (!keyExists) {
                logger.info("Fresh install detected, using default preset for pool initialization")
            }
        } else if let selectedPreset = HomeFeedPreferences.getSelectedPreset() {
            preset = selectedPreset
        } else {
            logger.warning("No preset selected, using empty pools")
            availableSelectionPool = []
            usedSelectionPool = []
            lastPreferencesHash = ""
            saveSelectionState()
            return
        }
        
        availableSelectionPool = []
        usedSelectionPool = []

        // Add enabled collections to the available pool
        for collection in preset.enabledCollections {
            availableSelectionPool.append("collection:\(collection)")
        }

        // Add saved identifiers to the available pool
        for savedIdentifier in preset.savedIdentifiers {
            availableSelectionPool.append("identifier:\(savedIdentifier.identifier)")
        }

        // Update the preferences hash
        lastPreferencesHash = generatePreferencesHash()

        // Save the initialized state
        saveSelectionState()

        logger.info("Initialized selection pools with \(self.availableSelectionPool.count) items from preset: \(preset.name)")
    }

    /// Checks if user preferences have changed and resets pools if needed
    private func checkAndUpdatePreferencesIfNeeded() {
        let currentHash = generatePreferencesHash()

        if currentHash != lastPreferencesHash {
            logger.info("User preferences have changed, resetting selection pools")
            initializeSelectionPools()
        }
    }

    // MARK: - Main Selection Methods

    /// The main method for selecting a random identifier based on current user preferences
    /// - Parameter allIdentifiers: The complete list of identifiers to select from if needed
    /// - Parameter collections: The available collections for selection
    /// - Returns: A randomly selected identifier based on user preferences
    func selectRandomIdentifier(from allIdentifiers: [ArchiveIdentifier], collections: [ArchiveCollection]) -> ArchiveIdentifier? {
        // Check if the key exists in UserDefaults
        let userDefaults = UserDefaults.standard
        let keyExists = userDefaults.object(forKey: "UseDefaultCollections") != nil
        
        // If key doesn't exist or is true, use default preset (handle fresh installs correctly)
        let useDefault = !keyExists || userDefaults.bool(forKey: "UseDefaultCollections")
        
        // Get the appropriate preset
        let preset: FeedPreset
        if !useDefault { // If "Use Default" is explicitly OFF - use user's preset
            logger.info("UserDefaults 'UseDefaultCollections' is explicitly false, using user's selected preset")
            if let selectedPreset = HomeFeedPreferences.getSelectedPreset() {
                preset = selectedPreset
            } else {
                logger.warning("No user preset selected, falling back to random selection")
                return allIdentifiers.randomElement()
            }
        } else { // If "Use Default" is ON or not set (fresh install) - use the default preset
            if (!keyExists) {
                logger.info("UserDefaults 'UseDefaultCollections' not set (fresh install), defaulting to default preset")
            } else {
                logger.info("UserDefaults 'UseDefaultCollections' is true, using default preset")
            }
            preset = DefaultPreset.getPreset()
        }
        
        // Use the same selection logic for both default and custom presets
        return selectWithPreset(preset: preset, allIdentifiers: allIdentifiers)
    }

    // MARK: - Preset-based Selection with Round-Robin

    /// Selects an identifier using a preset (either user's custom preset or default preset)
    /// - Parameters:
    ///   - preset: The preset to use for selection
    ///   - allIdentifiers: The fallback identifiers if selection fails
    /// - Returns: A randomly selected identifier based on the provided preset
    private func selectWithPreset(preset: FeedPreset, allIdentifiers: [ArchiveIdentifier]) -> ArchiveIdentifier? {
        logger.info("Using round-robin selection from preset: \(preset.name)")

        // Check if preferences have changed since last selection
        checkAndUpdatePreferencesIfNeeded()

        // Get collections and identifiers from the preset
        let enabledCollections = preset.enabledCollections
        let savedIdentifiers = preset.savedIdentifiers

        // If there are no enabled collections or saved identifiers, fall back to random selection
        if enabledCollections.isEmpty && savedIdentifiers.isEmpty {
            logger.warning("No enabled collections or saved identifiers found in preset, falling back to random selection")
            return allIdentifiers.randomElement()
        }

        // If the available pool is empty, reset by moving all used items back to available
        if availableSelectionPool.isEmpty {
            logger.info("Available selection pool is empty, resetting the round-robin cycle")
            availableSelectionPool = usedSelectionPool
            usedSelectionPool = []
            saveSelectionState()
        }

        // Randomly select from the available pool
        guard let selection = availableSelectionPool.randomElement(),
              let selectionIndex = availableSelectionPool.firstIndex(of: selection) else {
            logger.error("Failed to select from selection pool")
            return allIdentifiers.randomElement()
        }

        // Remove the selected item from available pool and add to used pool
        availableSelectionPool.remove(at: selectionIndex)
        usedSelectionPool.append(selection)

        // Save updated state
        saveSelectionState()

        logger.info("Selected item: \(selection) (Available: \(self.availableSelectionPool.count), Used: \(self.usedSelectionPool.count))")

        // Process the selected pool entry
        if selection.starts(with: "collection:") {
            // We selected a collection, get a random identifier from it
            let collectionName = String(selection.dropFirst("collection:".count))
            logger.debug("Selected collection: \(collectionName)")

            do {
                let collectionIdentifiers = try dbService.loadIdentifiersForCollection(collectionName)
                if collectionIdentifiers.isEmpty {
                    logger.warning("No identifiers found in selected collection \(collectionName), falling back to random selection")
                    return allIdentifiers.randomElement()
                }

                // Return a random identifier from the selected collection
                return collectionIdentifiers.randomElement()
            } catch {
                logger.error("Failed to load identifiers for collection \(collectionName): \(error.localizedDescription)")
                return allIdentifiers.randomElement()
            }
        } else if selection.starts(with: "identifier:") {
            // We selected a specific identifier
            let identifierString = String(selection.dropFirst("identifier:".count))
            logger.debug("Selected specific identifier: \(identifierString)")

            // Find the matching identifier
            if let matchingIdentifier = savedIdentifiers.first(where: { $0.identifier == identifierString })?.archiveIdentifier {
                return matchingIdentifier
            } else {
                logger.error("Selected identifier not found in preset's saved identifiers")
                return allIdentifiers.randomElement()
            }
        } else {
            // This shouldn't happen with our format, but handle it just in case
            logger.error("Invalid selection format: \(selection)")
            return allIdentifiers.randomElement()
        }
    }

}