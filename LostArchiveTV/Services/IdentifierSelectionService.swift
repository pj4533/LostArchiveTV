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
        let enabledCollections = HomeFeedPreferences.getEnabledCollections() ?? []
        let savedIdentifiers = UserSelectedIdentifiersManager.shared.getArchiveIdentifiers()

        // Create a deterministic string representing all user preferences
        let collectionsString = enabledCollections.sorted().joined(separator: ",")
        let identifiersString = savedIdentifiers.map { $0.identifier }.sorted().joined(separator: ",")

        return "\(collectionsString)|\(identifiersString)"
    }

    /// Initializes or resets the selection pools based on current user preferences
    private func initializeSelectionPools() {
        // Get user selected collections and individual identifiers
        let enabledCollections = HomeFeedPreferences.getEnabledCollections() ?? []
        let savedIdentifiers = UserSelectedIdentifiersManager.shared.getArchiveIdentifiers()

        availableSelectionPool = []
        usedSelectionPool = []

        // Add enabled collections to the available pool
        for collection in enabledCollections {
            availableSelectionPool.append("collection:\(collection)")
        }

        // Add saved identifiers to the available pool
        for savedIdentifier in savedIdentifiers {
            availableSelectionPool.append("identifier:\(savedIdentifier.identifier)")
        }

        // Update the preferences hash
        lastPreferencesHash = generatePreferencesHash()

        // Save the initialized state
        saveSelectionState()

        logger.info("Initialized selection pools with \(self.availableSelectionPool.count) items")
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
        // Check if user has custom home feed behavior
        if !HomeFeedPreferences.shouldUseDefaultCollections() {
            return selectWithCustomPreferences(allIdentifiers: allIdentifiers)
        } else {
            return selectWithDefaultBehavior(allIdentifiers: allIdentifiers, collections: collections)
        }
    }

    // MARK: - Custom Preferences Selection with Round-Robin

    /// Selects an identifier using the user's custom preferences with round-robin distribution
    /// - Parameter allIdentifiers: The fallback identifiers if custom selection fails
    /// - Returns: A randomly selected identifier based on user custom preferences
    private func selectWithCustomPreferences(allIdentifiers: [ArchiveIdentifier]) -> ArchiveIdentifier? {
        logger.info("Using round-robin selection from user custom preferences")

        // Check if preferences have changed since last selection
        checkAndUpdatePreferencesIfNeeded()

        // Get user selected collections and individual identifiers
        let enabledCollections = HomeFeedPreferences.getEnabledCollections() ?? []
        let savedIdentifiers = UserSelectedIdentifiersManager.shared.getArchiveIdentifiers()

        // If there are no enabled collections or saved identifiers, fall back to random selection
        if enabledCollections.isEmpty && savedIdentifiers.isEmpty {
            logger.warning("No enabled collections or saved identifiers found, falling back to random selection")
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
            if let matchingIdentifier = savedIdentifiers.first(where: { $0.identifier == identifierString }) {
                return matchingIdentifier
            } else {
                logger.error("Selected identifier not found in saved identifiers")
                return allIdentifiers.randomElement()
            }
        } else {
            // This shouldn't happen with our format, but handle it just in case
            logger.error("Invalid selection format: \(selection)")
            return allIdentifiers.randomElement()
        }
    }

    // MARK: - Default Behavior Selection

    /// Selects an identifier using the default behavior (preferred/non-preferred collections)
    /// - Parameters:
    ///   - allIdentifiers: All available identifiers
    ///   - collections: All available collections
    /// - Returns: A randomly selected identifier based on collection preferences
    private func selectWithDefaultBehavior(allIdentifiers: [ArchiveIdentifier], collections: [ArchiveCollection]) -> ArchiveIdentifier? {
        logger.info("Using default collection behavior for selection")

        guard !collections.isEmpty else {
            logger.error("No collections available for random selection")
            return allIdentifiers.randomElement()
        }

        // Filter out excluded collections first
        let allowedCollections = collections.filter { !$0.excluded }

        // If all collections are excluded, fall back to random selection
        guard !allowedCollections.isEmpty else {
            logger.warning("All collections are excluded, falling back to random selection")
            return allIdentifiers.randomElement()
        }

        // Separate collections into preferred and non-preferred (from non-excluded collections)
        let preferredCollections = allowedCollections.filter { $0.preferred }
        let nonPreferredCollections = allowedCollections.filter { !$0.preferred }

        // Create a selection pool where:
        // - Each preferred collection gets one entry
        // - All non-preferred collections together get one entry
        var selectionPool: [String] = preferredCollections.map { $0.name }
        if !nonPreferredCollections.isEmpty {
            selectionPool.append("non-preferred")
        }

        logger.info("Collection pool (default behavior): \(selectionPool)")

        // Randomly select from the pool
        guard let selection = selectionPool.randomElement() else {
            logger.error("Failed to select from collection pool")
            return allIdentifiers.randomElement()
        }

        if selection == "non-preferred" {
            // Randomly select one of the non-preferred collections
            guard let randomNonPreferredCollection = nonPreferredCollections.randomElement() else {
                logger.error("Failed to select a non-preferred collection")
                return allIdentifiers.randomElement()
            }

            // Filter identifiers for the selected non-preferred collection
            let collectionIdentifiers = allIdentifiers.filter { $0.collection == randomNonPreferredCollection.name }

            if collectionIdentifiers.isEmpty {
                logger.warning("No identifiers found for non-preferred collection '\(randomNonPreferredCollection.name)', selecting from all identifiers")
                return allIdentifiers.randomElement()
            }

            logger.debug("Selected non-preferred collection: \(randomNonPreferredCollection.name)")
            return collectionIdentifiers.randomElement()
        } else {
            // We selected a specific preferred collection
            // Filter identifiers for the selected preferred collection
            let collectionIdentifiers = allIdentifiers.filter { $0.collection == selection }

            if collectionIdentifiers.isEmpty {
                logger.warning("No identifiers found for preferred collection '\(selection)', selecting from all identifiers")
                return allIdentifiers.randomElement()
            }

            logger.debug("Selected preferred collection: \(selection)")
            return collectionIdentifiers.randomElement()
        }
    }
}