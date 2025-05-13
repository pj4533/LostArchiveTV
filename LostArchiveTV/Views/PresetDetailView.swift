import SwiftUI

struct PresetDetailView: View {
    @ObservedObject var viewModel: HomeFeedSettingsViewModel
    @Environment(\.presentationMode) var presentationMode
    let preset: FeedPreset
    @State private var showDeleteConfirmation = false
    @State private var identifiersViewModel = IdentifiersSettingsViewModel()
    @State private var showEditNameAlert = false
    @State private var editingName: String = ""
    
    init(viewModel: HomeFeedSettingsViewModel, preset: FeedPreset) {
        self.viewModel = viewModel
        self.preset = preset
        self._editingName = State(initialValue: preset.name)
    }
    
    var body: some View {
        List {
            Section(header: Text("Collections")) {
                NavigationLink(destination: CollectionsView(viewModel: viewModel)) {
                    HStack {
                        Text("Collection Settings")
                        Spacer()
                        Text("\(viewModel.collections.filter { $0.isEnabled }.count) selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section(header: Text("Saved Videos")) {
                NavigationLink(destination: IdentifiersView(viewModel: identifiersViewModel)) {
                    HStack {
                        Text("Saved Identifiers")
                        Spacer()
                        Text("\(identifiersViewModel.identifiers.count) saved")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section {
                Button(role: .destructive, action: {
                    showDeleteConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Preset")
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle(preset.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showEditNameAlert = true
                    editingName = preset.name
                }) {
                    Text("Rename")
                }
            }
        }
        .onAppear {
            identifiersViewModel.loadIdentifiers()
        }
        .alert("Delete Preset", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                viewModel.deletePreset(withId: preset.id)
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this preset? This action cannot be undone.")
        }
        .alert("Edit Preset Name", isPresented: $showEditNameAlert) {
            TextField("Preset Name", text: $editingName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                savePresetName()
            }
        } message: {
            Text("Enter a new name for this preset:")
        }
    }
    
    private func savePresetName() {
        if !editingName.isEmpty && editingName != preset.name {
            var updatedPreset = preset
            updatedPreset.name = editingName
            viewModel.updatePreset(updatedPreset)
        }
    }
}