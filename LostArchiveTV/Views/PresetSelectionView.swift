import SwiftUI

struct PresetSelectionView: View {
    @ObservedObject var viewModel: HomeFeedSettingsViewModel
    @State private var showingNewPresetAlert = false
    @State private var newPresetName = ""
    @Binding var isPresented: Bool
    var identifier: String
    var title: String
    var collection: String
    var fileCount: Int
    
    // Callback for when identifier is saved
    var onSave: ((String, String?) -> Void)?
    
    init(viewModel: HomeFeedSettingsViewModel, isPresented: Binding<Bool>, identifier: String, title: String, collection: String, fileCount: Int, onSave: ((String, String?) -> Void)? = nil) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        self.identifier = identifier
        self.title = title
        self.collection = collection
        self.fileCount = fileCount
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Select Preset")) {
                    ForEach(viewModel.presets) { preset in
                        HStack {
                            Text(preset.name)
                            Spacer()
                            if preset.isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            saveIdentifierToPreset(preset: preset)
                        }
                    }
                    
                    Button(action: {
                        showingNewPresetAlert = true
                        newPresetName = ""
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("Create New Preset")
                        }
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How saved videos work")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                        
                        Text("Videos saved to presets will appear in your feed when that preset is selected. Videos can be saved to multiple presets.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Save to Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        isPresented = false
                    }
                }
            }
            .onAppear {
                viewModel.loadPresets()
            }
        }
        .alert("New Preset", isPresented: $showingNewPresetAlert) {
            TextField("Preset Name", text: $newPresetName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                if !newPresetName.isEmpty {
                    createNewPresetAndSaveIdentifier()
                }
            }
        } message: {
            Text("Enter a name for your new preset:")
        }
    }
    
    private func saveIdentifierToPreset(preset: FeedPreset) {
        // Create the new saved identifier
        let newSavedIdentifier = UserSelectedIdentifier(
            id: identifier,
            identifier: identifier,
            title: title,
            collection: collection,
            fileCount: fileCount
        )
        
        // Check if the identifier is already in the preset
        let alreadyExists = preset.savedIdentifiers.contains(where: { $0.identifier == identifier })
        
        if !alreadyExists {
            // Add to the preset
            var updatedPreset = preset
            updatedPreset.savedIdentifiers.append(newSavedIdentifier)
            viewModel.updatePreset(updatedPreset)
            
            // Add to general saved identifiers as well
            if !UserSelectedIdentifiersManager.shared.contains(identifier: identifier) {
                UserSelectedIdentifiersManager.shared.addIdentifier(newSavedIdentifier)
            }
            
            // Call the onSave callback instead of using notifications
            onSave?(title, preset.name)
        }
        
        // Close the sheet
        isPresented = false
    }
    
    private func createNewPresetAndSaveIdentifier() {
        // Create new preset with current settings and add the identifier
        let enabledCollectionIds = viewModel.collections
            .filter { $0.isEnabled }
            .map { $0.id }
        
        // Create identifier
        let newSavedIdentifier = UserSelectedIdentifier(
            id: identifier,
            identifier: identifier,
            title: title,
            collection: collection,
            fileCount: fileCount
        )
        
        // Create new preset
        let newPreset = FeedPreset(
            name: newPresetName,
            enabledCollections: enabledCollectionIds,
            savedIdentifiers: [newSavedIdentifier],
            isSelected: false // Don't auto-select the new preset
        )
        
        HomeFeedPreferences.addPreset(newPreset)
        viewModel.loadPresets()
        
        // Add to general saved identifiers if not already there
        if !UserSelectedIdentifiersManager.shared.contains(identifier: identifier) {
            UserSelectedIdentifiersManager.shared.addIdentifier(newSavedIdentifier)
        }
        
        // Call the onSave callback instead of using notifications
        onSave?(title, newPresetName)
        
        // Close the sheet
        isPresented = false
    }
}