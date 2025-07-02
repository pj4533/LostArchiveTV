import Testing
import Combine
import Foundation
@testable import LATV

@MainActor
@Suite(.serialized)
struct PresetManagerCombineTests {
    
    // Helper to ensure clean state between tests
    func cleanupTestPresets() {
        let allPresets = HomeFeedPreferences.getAllPresets()
        for preset in allPresets where preset.id.contains("test-") || preset.id.contains("Test") {
            HomeFeedPreferences.deletePreset(withId: preset.id)
        }
    }
    
    // MARK: - Add Identifier to Current Preset Tests
    
    @Test
    func addIdentifierToCurrentPreset_updatesCountImmediately() async {
        // Arrange
        cleanupTestPresets()
        let manager = PresetManager.shared
        var cancellables = Set<AnyCancellable>()
        var identifierCounts: [Int] = []
        
        // Create a unique test preset with no identifiers
        let uniqueId = "test-preset-add-current-\(UUID().uuidString)"
        let testPreset = FeedPreset(
            id: uniqueId,
            name: "Test Preset",
            enabledCollections: ["test-collection"],
            savedIdentifiers: [],
            isSelected: true
        )
        HomeFeedPreferences.addPreset(testPreset)
        
        // Select the preset and wait for sync
        HomeFeedPreferences.selectPreset(withId: uniqueId)
        try? await Task.sleep(for: .milliseconds(100))
        
        // Verify initial state
        let selectedPreset = manager.getSelectedPreset()
        #expect(selectedPreset?.id == uniqueId)
        #expect(manager.identifiers.count == 0)
        
        // Subscribe to @Published identifiers property
        manager.$identifiers
            .sink { identifiers in
                identifierCounts.append(identifiers.count)
            }
            .store(in: &cancellables)
        
        // Act
        let newIdentifier = UserSelectedIdentifier(
            id: "test-identifier-1",
            identifier: "test-identifier-1",
            title: "Test Video 1",
            collection: "test-collection",
            fileCount: 1
        )
        manager.addIdentifier(newIdentifier)
        
        // Wait a moment for publishers to emit
        try? await Task.sleep(for: .milliseconds(50))
        
        // Assert
        #expect(manager.identifiers.count == 1)
        #expect(manager.identifiers.first?.id == "test-identifier-1")
        // Should have captured: initial value (0) and updated value (1)
        #expect(identifierCounts.contains(0))
        #expect(identifierCounts.contains(1))
        
        // Cleanup
        HomeFeedPreferences.deletePreset(withId: uniqueId)
    }
    
    @Test
    func addIdentifierToCurrentPreset_sendsCorrectEvent() async {
        // Arrange
        cleanupTestPresets()
        let manager = PresetManager.shared
        var cancellables = Set<AnyCancellable>()
        var receivedEvent: PresetEvent?
        
        // Create a unique test preset
        let uniqueId = "test-preset-add-event-\(UUID().uuidString)"
        let testPreset = FeedPreset(
            id: uniqueId,
            name: "Test Preset",
            enabledCollections: ["test-collection"],
            savedIdentifiers: [],
            isSelected: true
        )
        HomeFeedPreferences.addPreset(testPreset)
        HomeFeedPreferences.selectPreset(withId: uniqueId)
        try? await Task.sleep(for: .milliseconds(100))
        
        // Subscribe to preset events
        manager.presetEvents
            .sink { event in
                receivedEvent = event
            }
            .store(in: &cancellables)
        
        // Act
        let newIdentifier = UserSelectedIdentifier(
            id: "test-identifier-2",
            identifier: "test-identifier-2",
            title: "Test Video 2",
            collection: "test-collection",
            fileCount: 1
        )
        manager.addIdentifier(newIdentifier)
        
        // Wait for event
        try? await Task.sleep(for: .milliseconds(50))
        
        // Assert
        if case let .identifierAdded(identifier, presetId) = receivedEvent {
            #expect(identifier.id == "test-identifier-2")
            #expect(presetId == uniqueId)
        } else {
            Issue.record("Expected identifierAdded event but got \(String(describing: receivedEvent))")
        }
        
        // Cleanup
        HomeFeedPreferences.deletePreset(withId: uniqueId)
    }
    
    // MARK: - Remove Identifier from Current Preset Tests
    
    @Test
    func removeIdentifierFromCurrentPreset_updatesCountImmediately() async {
        // Arrange
        cleanupTestPresets()
        let manager = PresetManager.shared
        var cancellables = Set<AnyCancellable>()
        var identifierCounts: [Int] = []
        
        // Create preset with existing identifiers
        let uniqueId = "test-preset-remove-current-\(UUID().uuidString)"
        let existingIdentifier = UserSelectedIdentifier(
            id: "existing-1",
            identifier: "existing-1",
            title: "Existing Video",
            collection: "test-collection",
            fileCount: 1
        )
        let testPreset = FeedPreset(
            id: uniqueId,
            name: "Test Preset",
            enabledCollections: ["test-collection"],
            savedIdentifiers: [existingIdentifier],
            isSelected: true
        )
        HomeFeedPreferences.addPreset(testPreset)
        HomeFeedPreferences.selectPreset(withId: uniqueId)
        try? await Task.sleep(for: .milliseconds(100))
        
        // Verify initial state
        #expect(manager.identifiers.count == 1)
        
        // Subscribe to @Published identifiers property
        manager.$identifiers
            .sink { identifiers in
                identifierCounts.append(identifiers.count)
            }
            .store(in: &cancellables)
        
        // Act
        manager.removeIdentifier(withId: "existing-1")
        
        // Wait for publishers
        try? await Task.sleep(for: .milliseconds(50))
        
        // Assert
        #expect(manager.identifiers.count == 0)
        #expect(identifierCounts.contains(1)) // Initial count
        #expect(identifierCounts.contains(0)) // After removal
        
        // Cleanup
        HomeFeedPreferences.deletePreset(withId: uniqueId)
    }
    
    @Test
    func removeIdentifierFromCurrentPreset_sendsCorrectEvent() async {
        // Arrange
        cleanupTestPresets()
        let manager = PresetManager.shared
        var cancellables = Set<AnyCancellable>()
        var receivedEvent: PresetEvent?
        
        // Create preset with existing identifier
        let uniqueId = "test-preset-remove-event-\(UUID().uuidString)"
        let existingIdentifier = UserSelectedIdentifier(
            id: "to-remove",
            identifier: "to-remove",
            title: "Video to Remove",
            collection: "test-collection",
            fileCount: 1
        )
        let testPreset = FeedPreset(
            id: uniqueId,
            name: "Test Preset",
            enabledCollections: ["test-collection"],
            savedIdentifiers: [existingIdentifier],
            isSelected: true
        )
        HomeFeedPreferences.addPreset(testPreset)
        HomeFeedPreferences.selectPreset(withId: uniqueId)
        try? await Task.sleep(for: .milliseconds(100))
        
        // Subscribe to preset events
        manager.presetEvents
            .sink { event in
                receivedEvent = event
            }
            .store(in: &cancellables)
        
        // Act
        manager.removeIdentifier(withId: "to-remove")
        
        // Wait for event
        try? await Task.sleep(for: .milliseconds(50))
        
        // Assert
        if case let .identifierRemoved(id, presetId) = receivedEvent {
            #expect(id == "to-remove")
            #expect(presetId == uniqueId)
        } else {
            Issue.record("Expected identifierRemoved event but got \(String(describing: receivedEvent))")
        }
        
        // Cleanup
        HomeFeedPreferences.deletePreset(withId: uniqueId)
    }
    
    // MARK: - Add Identifier to Non-Current Preset Tests
    
    @Test
    func addIdentifierToNonCurrentPreset_doesNotUpdateCurrentIdentifiers() async {
        // Arrange
        cleanupTestPresets()
        let manager = PresetManager.shared
        var cancellables = Set<AnyCancellable>()
        var identifierCounts: [Int] = []
        
        // Create current preset and non-current preset
        let currentPresetId = "current-preset-\(UUID().uuidString)"
        let otherPresetId = "other-preset-\(UUID().uuidString)"
        
        let currentPreset = FeedPreset(
            id: currentPresetId,
            name: "Current Preset",
            enabledCollections: ["test-collection"],
            savedIdentifiers: [],
            isSelected: true
        )
        let otherPreset = FeedPreset(
            id: otherPresetId,
            name: "Other Preset",
            enabledCollections: ["test-collection"],
            savedIdentifiers: [],
            isSelected: false
        )
        
        HomeFeedPreferences.addPreset(currentPreset)
        HomeFeedPreferences.addPreset(otherPreset)
        HomeFeedPreferences.selectPreset(withId: currentPresetId)
        try? await Task.sleep(for: .milliseconds(100))
        
        // Verify initial state
        #expect(manager.getSelectedPreset()?.id == currentPresetId)
        #expect(manager.identifiers.count == 0)
        
        // Subscribe to @Published identifiers property
        manager.$identifiers
            .sink { identifiers in
                identifierCounts.append(identifiers.count)
            }
            .store(in: &cancellables)
        
        // Act - add identifier to non-current preset
        let newIdentifier = UserSelectedIdentifier(
            id: "other-identifier",
            identifier: "other-identifier",
            title: "Other Video",
            collection: "test-collection",
            fileCount: 1
        )
        manager.addIdentifier(newIdentifier, toPresetWithId: otherPresetId)
        
        // Wait for any potential updates
        try? await Task.sleep(for: .milliseconds(100))
        
        // Assert
        // Current preset identifiers should remain unchanged
        #expect(manager.identifiers.count == 0)
        // Only the initial count should be recorded
        #expect(identifierCounts.allSatisfy { $0 == 0 })
        
        // Verify the other preset was updated
        let otherPresetIdentifiers = manager.getIdentifiers(fromPresetWithId: otherPresetId)
        #expect(otherPresetIdentifiers.count == 1)
        #expect(otherPresetIdentifiers.first?.id == "other-identifier")
        
        // Cleanup
        HomeFeedPreferences.deletePreset(withId: currentPresetId)
        HomeFeedPreferences.deletePreset(withId: otherPresetId)
    }
    
    @Test
    func addIdentifierToNonCurrentPreset_stillSendsEvent() async {
        // Arrange
        cleanupTestPresets()
        let manager = PresetManager.shared
        var cancellables = Set<AnyCancellable>()
        var receivedEvent: PresetEvent?
        
        // Create current and other preset
        let currentPresetId = "current-event-\(UUID().uuidString)"
        let otherPresetId = "other-event-\(UUID().uuidString)"
        
        let currentPreset = FeedPreset(
            id: currentPresetId,
            name: "Current Preset",
            enabledCollections: ["test-collection"],
            savedIdentifiers: [],
            isSelected: true
        )
        let otherPreset = FeedPreset(
            id: otherPresetId,
            name: "Other Preset",
            enabledCollections: ["test-collection"],
            savedIdentifiers: [],
            isSelected: false
        )
        
        HomeFeedPreferences.addPreset(currentPreset)
        HomeFeedPreferences.addPreset(otherPreset)
        HomeFeedPreferences.selectPreset(withId: currentPresetId)
        try? await Task.sleep(for: .milliseconds(100))
        
        // Subscribe to preset events
        manager.presetEvents
            .sink { event in
                receivedEvent = event
            }
            .store(in: &cancellables)
        
        // Act
        let newIdentifier = UserSelectedIdentifier(
            id: "non-current-identifier",
            identifier: "non-current-identifier",
            title: "Non-Current Video",
            collection: "test-collection",
            fileCount: 1
        )
        manager.addIdentifier(newIdentifier, toPresetWithId: otherPresetId)
        
        // Wait for event
        try? await Task.sleep(for: .milliseconds(50))
        
        // Assert
        if case let .identifierAdded(identifier, presetId) = receivedEvent {
            #expect(identifier.id == "non-current-identifier")
            #expect(presetId == otherPresetId)
        } else {
            Issue.record("Expected identifierAdded event but got \(String(describing: receivedEvent))")
        }
        
        // Cleanup
        HomeFeedPreferences.deletePreset(withId: currentPresetId)
        HomeFeedPreferences.deletePreset(withId: otherPresetId)
    }
    
    // MARK: - Remove Identifier from Non-Current Preset Tests
    
    @Test
    func removeIdentifierFromNonCurrentPreset_doesNotUpdateCurrentIdentifiers() async {
        // Arrange
        let manager = PresetManager.shared
        var cancellables = Set<AnyCancellable>()
        var identifierCountChanges = 0
        
        // Clean up any existing test presets first
        let allPresets = HomeFeedPreferences.getAllPresets()
        for preset in allPresets where preset.id.hasPrefix("current-remove-") || preset.id.hasPrefix("other-remove-") {
            HomeFeedPreferences.deletePreset(withId: preset.id)
        }
        
        // Create presets
        let currentPresetId = "current-remove-\(UUID().uuidString)"
        let otherPresetId = "other-remove-\(UUID().uuidString)"
        
        let currentIdentifier = UserSelectedIdentifier(
            id: "current-id",
            identifier: "current-id",
            title: "Current Video",
            collection: "test-collection",
            fileCount: 1
        )
        let otherIdentifier = UserSelectedIdentifier(
            id: "other-id",
            identifier: "other-id",
            title: "Other Video",
            collection: "test-collection",
            fileCount: 1
        )
        
        let currentPreset = FeedPreset(
            id: currentPresetId,
            name: "Current Preset",
            enabledCollections: ["test-collection"],
            savedIdentifiers: [currentIdentifier],
            isSelected: false
        )
        let otherPreset = FeedPreset(
            id: otherPresetId,
            name: "Other Preset",
            enabledCollections: ["test-collection"],
            savedIdentifiers: [otherIdentifier],
            isSelected: false
        )
        
        HomeFeedPreferences.addPreset(currentPreset)
        HomeFeedPreferences.addPreset(otherPreset)
        HomeFeedPreferences.selectPreset(withId: currentPresetId)
        try? await Task.sleep(for: .milliseconds(200))
        
        // Force refresh to ensure manager is synced
        _ = manager.getSelectedPreset()
        
        // Verify initial state
        #expect(manager.getSelectedPreset()?.id == currentPresetId)
        #expect(manager.identifiers.count == 1)
        #expect(manager.identifiers.first?.id == "current-id")
        
        // Subscribe to changes (skip initial value)
        manager.$identifiers
            .dropFirst()
            .sink { _ in
                identifierCountChanges += 1
            }
            .store(in: &cancellables)
        
        // Act - remove from non-current preset using PresetManager method
        // First, verify the other preset has the identifier
        let otherPresetIdentifiers = manager.getIdentifiers(fromPresetWithId: otherPresetId)
        #expect(otherPresetIdentifiers.count == 1)
        #expect(otherPresetIdentifiers.first?.id == "other-id")
        
        // Remove identifier from other preset using direct preset update
        // This simulates removing from a non-current preset without using the manager's remove method
        var updatedOtherPreset = otherPreset
        updatedOtherPreset.savedIdentifiers = []
        HomeFeedPreferences.updatePreset(updatedOtherPreset)
        
        // Wait for any potential updates
        try? await Task.sleep(for: .milliseconds(100))
        
        // Assert
        // Current preset identifiers should remain unchanged
        #expect(manager.identifiers.count == 1)
        #expect(manager.identifiers.first?.id == "current-id")
        #expect(identifierCountChanges == 0) // No changes to current preset's identifiers
        
        // Verify other preset was updated
        let updatedOtherIdentifiers = manager.getIdentifiers(fromPresetWithId: otherPresetId)
        #expect(updatedOtherIdentifiers.count == 0)
        
        // Cleanup
        HomeFeedPreferences.deletePreset(withId: currentPresetId)
        HomeFeedPreferences.deletePreset(withId: otherPresetId)
    }
    
    // MARK: - Rapid Add/Remove Tests
    
    @Test
    func rapidAddRemoveOperations_maintainsAccurateCounts() async {
        // Arrange
        cleanupTestPresets()
        let manager = PresetManager.shared
        var cancellables = Set<AnyCancellable>()
        var recordedCounts: [Int] = []
        var eventCount = 0
        
        // Create test preset
        let uniqueId = "rapid-test-\(UUID().uuidString)"
        let testPreset = FeedPreset(
            id: uniqueId,
            name: "Rapid Test Preset",
            enabledCollections: ["test-collection"],
            savedIdentifiers: [],
            isSelected: true
        )
        HomeFeedPreferences.addPreset(testPreset)
        HomeFeedPreferences.selectPreset(withId: uniqueId)
        try? await Task.sleep(for: .milliseconds(100))
        
        // Subscribe to both publishers
        manager.$identifiers
            .sink { identifiers in
                recordedCounts.append(identifiers.count)
            }
            .store(in: &cancellables)
        
        manager.presetEvents
            .sink { event in
                switch event {
                case .identifierAdded, .identifierRemoved:
                    eventCount += 1
                default:
                    break
                }
            }
            .store(in: &cancellables)
        
        // Act - perform rapid operations
        let identifiers = (1...5).map { index in
            UserSelectedIdentifier(
                id: "rapid-\(index)",
                identifier: "rapid-\(index)",
                title: "Rapid Video \(index)",
                collection: "test-collection",
                fileCount: 1
            )
        }
        
        // Add all identifiers rapidly
        for identifier in identifiers {
            manager.addIdentifier(identifier)
        }
        
        // Remove some identifiers
        manager.removeIdentifier(withId: "rapid-2")
        manager.removeIdentifier(withId: "rapid-4")
        
        // Add one more
        let extraIdentifier = UserSelectedIdentifier(
            id: "rapid-extra",
            identifier: "rapid-extra",
            title: "Extra Video",
            collection: "test-collection",
            fileCount: 1
        )
        manager.addIdentifier(extraIdentifier)
        
        // Wait for all operations to complete
        try? await Task.sleep(for: .milliseconds(200))
        
        // Assert
        // Final count should be: 5 added - 2 removed + 1 added = 4
        #expect(manager.identifiers.count == 4)
        
        // Verify recorded counts include the final count
        #expect(recordedCounts.contains(4))
        
        // Should have received events for all operations (5 adds + 2 removes + 1 add = 8)
        #expect(eventCount == 8)
        
        // Verify specific identifiers remain
        let finalIdentifiers = manager.identifiers
        #expect(finalIdentifiers.contains(where: { $0.id == "rapid-1" }))
        #expect(finalIdentifiers.contains(where: { $0.id == "rapid-3" }))
        #expect(finalIdentifiers.contains(where: { $0.id == "rapid-5" }))
        #expect(finalIdentifiers.contains(where: { $0.id == "rapid-extra" }))
        #expect(!finalIdentifiers.contains(where: { $0.id == "rapid-2" }))
        #expect(!finalIdentifiers.contains(where: { $0.id == "rapid-4" }))
        
        // Cleanup
        HomeFeedPreferences.deletePreset(withId: uniqueId)
    }
    
    @Test
    func concurrentAddRemoveOperations_maintainsConsistency() async {
        // Arrange
        cleanupTestPresets()
        let manager = PresetManager.shared
        var cancellables = Set<AnyCancellable>()
        var finalCount = 0
        
        // Create test preset
        let uniqueId = "concurrent-test-\(UUID().uuidString)"
        let testPreset = FeedPreset(
            id: uniqueId,
            name: "Concurrent Test Preset",
            enabledCollections: ["test-collection"],
            savedIdentifiers: [],
            isSelected: true
        )
        HomeFeedPreferences.addPreset(testPreset)
        HomeFeedPreferences.selectPreset(withId: uniqueId)
        try? await Task.sleep(for: .milliseconds(100))
        
        // Subscribe to final state
        manager.$identifiers
            .sink { identifiers in
                finalCount = identifiers.count
            }
            .store(in: &cancellables)
        
        // Act - simulate concurrent operations
        await withTaskGroup(of: Void.self) { group in
            // Add operations
            for i in 1...10 {
                group.addTask {
                    let identifier = UserSelectedIdentifier(
                        id: "concurrent-\(i)",
                        identifier: "concurrent-\(i)",
                        title: "Concurrent Video \(i)",
                        collection: "test-collection",
                        fileCount: 1
                    )
                    await manager.addIdentifier(identifier)
                }
            }
            
            // Wait for adds to complete
            await group.waitForAll()
            
            // Remove some items
            for i in [2, 4, 6, 8] {
                group.addTask {
                    await manager.removeIdentifier(withId: "concurrent-\(i)")
                }
            }
        }
        
        // Wait for all operations to settle
        try? await Task.sleep(for: .milliseconds(200))
        
        // Assert
        // Should have 10 added - 4 removed = 6
        #expect(finalCount == 6)
        #expect(manager.identifiers.count == 6)
        
        // Verify the correct items remain
        let remainingIds = manager.identifiers.map { $0.id }
        #expect(remainingIds.contains("concurrent-1"))
        #expect(remainingIds.contains("concurrent-3"))
        #expect(remainingIds.contains("concurrent-5"))
        #expect(remainingIds.contains("concurrent-7"))
        #expect(remainingIds.contains("concurrent-9"))
        #expect(remainingIds.contains("concurrent-10"))
        
        // Cleanup
        HomeFeedPreferences.deletePreset(withId: uniqueId)
    }
}