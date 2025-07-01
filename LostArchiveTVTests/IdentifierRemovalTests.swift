import Testing
import Foundation
import Combine
@testable import LATV

@MainActor
@Suite(.serialized)
struct IdentifierRemovalTests {
    
    @Test
    func removeIdentifierFromSpecificPreset_removesSuccessfully() async {
        // Arrange
        let manager = PresetManager.shared
        
        // Create a test preset with identifiers
        let uniqueId = "test-preset-removal-\(UUID().uuidString)"
        let identifier1 = UserSelectedIdentifier(
            id: "test-id-1",
            identifier: "test-identifier-1",
            title: "Test Video 1",
            collection: "test-collection",
            fileCount: 1
        )
        let identifier2 = UserSelectedIdentifier(
            id: "test-id-2",
            identifier: "test-identifier-2",
            title: "Test Video 2",
            collection: "test-collection",
            fileCount: 1
        )
        
        let testPreset = FeedPreset(
            id: uniqueId,
            name: "Test Preset",
            enabledCollections: ["test-collection"],
            savedIdentifiers: [identifier1, identifier2],
            isSelected: false
        )
        HomeFeedPreferences.addPreset(testPreset)
        
        // Act - Remove identifier from specific preset
        let result = manager.removeIdentifier(withId: identifier1.id, fromPresetWithId: uniqueId)
        
        // Assert
        #expect(result == true)
        
        // Verify the identifier was removed
        let updatedPreset = HomeFeedPreferences.getAllPresets().first(where: { $0.id == uniqueId })
        #expect(updatedPreset != nil)
        #expect(updatedPreset?.savedIdentifiers.count == 1)
        #expect(updatedPreset?.savedIdentifiers.first?.id == identifier2.id)
        
        // Cleanup
        HomeFeedPreferences.deletePreset(withId: uniqueId)
    }
    
    @Test
    func identifiersSettingsViewModel_removeIdentifierFromSpecificPreset_updatesCorrectly() async {
        // Arrange
        _ = PresetManager.shared
        
        // Create a test preset with identifiers
        let uniqueId = "test-preset-viewmodel-\(UUID().uuidString)"
        let identifier1 = UserSelectedIdentifier(
            id: "test-vm-id-1",
            identifier: "test-vm-identifier-1",
            title: "Test VM Video 1",
            collection: "test-collection",
            fileCount: 1
        )
        let identifier2 = UserSelectedIdentifier(
            id: "test-vm-id-2",
            identifier: "test-vm-identifier-2",
            title: "Test VM Video 2",
            collection: "test-collection",
            fileCount: 1
        )
        
        let testPreset = FeedPreset(
            id: uniqueId,
            name: "Test VM Preset",
            enabledCollections: ["test-collection"],
            savedIdentifiers: [identifier1, identifier2],
            isSelected: false
        )
        HomeFeedPreferences.addPreset(testPreset)
        
        // Create view model with specific preset
        let viewModel = IdentifiersSettingsViewModel(preset: testPreset)
        
        // Verify initial state
        #expect(viewModel.identifiers.count == 2)
        
        // Act - Remove identifier through view model
        viewModel.removeIdentifier(identifier1.id)
        
        // Wait for async operations
        try? await Task.sleep(for: .milliseconds(100))
        
        // Assert - View model should be updated
        #expect(viewModel.identifiers.count == 1)
        #expect(viewModel.identifiers.first?.id == identifier2.id)
        
        // Verify the preset in storage was updated
        let updatedPreset = HomeFeedPreferences.getAllPresets().first(where: { $0.id == uniqueId })
        #expect(updatedPreset?.savedIdentifiers.count == 1)
        #expect(updatedPreset?.savedIdentifiers.first?.id == identifier2.id)
        
        // Cleanup
        HomeFeedPreferences.deletePreset(withId: uniqueId)
    }
    
    @Test
    func removeIdentifierSendsCorrectEvent() async {
        // Arrange
        let manager = PresetManager.shared
        var receivedEvent: PresetEvent?
        var cancellables = Set<AnyCancellable>()
        
        // Create a test preset
        let uniqueId = "test-preset-event-\(UUID().uuidString)"
        let identifier = UserSelectedIdentifier(
            id: "test-event-id",
            identifier: "test-event-identifier",
            title: "Test Event Video",
            collection: "test-collection",
            fileCount: 1
        )
        
        let testPreset = FeedPreset(
            id: uniqueId,
            name: "Test Event Preset",
            enabledCollections: ["test-collection"],
            savedIdentifiers: [identifier],
            isSelected: false
        )
        HomeFeedPreferences.addPreset(testPreset)
        
        // Subscribe to events
        manager.presetEvents
            .sink { event in
                if case .identifierRemoved(let id, let presetId) = event {
                    receivedEvent = event
                }
            }
            .store(in: &cancellables)
        
        // Act - Remove identifier
        manager.removeIdentifier(withId: identifier.id, fromPresetWithId: uniqueId)
        
        // Wait for event
        try? await Task.sleep(for: .milliseconds(100))
        
        // Assert
        #expect(receivedEvent != nil)
        if case .identifierRemoved(let id, let presetId) = receivedEvent {
            #expect(id == identifier.id)
            #expect(presetId == uniqueId)
        }
        
        // Cleanup
        HomeFeedPreferences.deletePreset(withId: uniqueId)
    }
    
    @Test
    func identifiersViewModelReloadsAfterRemoval() async {
        // Arrange
        let uniqueId = "test-preset-reload-\(UUID().uuidString)"
        let identifier1 = UserSelectedIdentifier(
            id: "reload-id-1",
            identifier: "reload-identifier-1",
            title: "Reload Video 1",
            collection: "test-collection",
            fileCount: 1
        )
        let identifier2 = UserSelectedIdentifier(
            id: "reload-id-2",
            identifier: "reload-identifier-2",
            title: "Reload Video 2",
            collection: "test-collection",
            fileCount: 1
        )
        
        let testPreset = FeedPreset(
            id: uniqueId,
            name: "Reload Test Preset",
            enabledCollections: ["test-collection"],
            savedIdentifiers: [identifier1, identifier2],
            isSelected: false
        )
        HomeFeedPreferences.addPreset(testPreset)
        
        // Create view model
        let viewModel = IdentifiersSettingsViewModel(preset: testPreset)
        #expect(viewModel.identifiers.count == 2)
        
        // Act - Remove through PresetManager directly (simulating removal from another view)
        PresetManager.shared.removeIdentifier(withId: identifier1.id, fromPresetWithId: uniqueId)
        
        // Reload the view model
        viewModel.loadIdentifiers()
        
        // Assert - View model should reflect the change
        #expect(viewModel.identifiers.count == 1)
        #expect(viewModel.identifiers.first?.id == identifier2.id)
        
        // Cleanup
        HomeFeedPreferences.deletePreset(withId: uniqueId)
    }
}