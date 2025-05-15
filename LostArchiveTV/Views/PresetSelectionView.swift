import SwiftUI

struct PresetSelectionView: View {
    @StateObject private var viewModel = PresetSelectionViewModel()
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
        // We only keep the signature for compatibility, but use our own view model
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
        let result = viewModel.saveIdentifierToPreset(
            preset: preset,
            identifier: identifier,
            title: title,
            collection: collection,
            fileCount: fileCount
        )
        
        if !result.isDuplicate {
            // Call the onSave callback
            onSave?(result.title, result.presetName)
        } else {
            // Use notification for duplicate case
            NotificationCenter.default.post(
                name: Notification.Name("ShowIdentifierNotification"),
                object: nil,
                userInfo: [
                    "title": result.title,
                    "presetName": result.presetName,
                    "isDuplicate": true
                ]
            )
        }
        
        // Close the sheet
        isPresented = false
    }
    
    private func createNewPresetAndSaveIdentifier() {
        let result = viewModel.createNewPresetAndSaveIdentifier(
            name: newPresetName,
            identifier: identifier,
            title: title, 
            collection: collection,
            fileCount: fileCount
        )
        
        // Call the onSave callback
        onSave?(result.title, result.presetName)
        
        // Close the sheet
        isPresented = false
    }
}