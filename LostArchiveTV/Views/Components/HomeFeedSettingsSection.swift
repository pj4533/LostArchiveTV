import SwiftUI
import OSLog

struct HomeFeedSettingsSection: View {
    @ObservedObject var viewModel: HomeFeedSettingsViewModel
    @State private var showingNewPresetAlert = false
    @State private var newPresetName = ""
    @State private var useDefault: Bool
    
    private let logger = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "HomeFeedSettings")
    
    init(viewModel: HomeFeedSettingsViewModel) {
        self.viewModel = viewModel
        // Initialize from the source of truth in UserDefaults
        self._useDefault = State(initialValue: UserDefaults.standard.bool(forKey: "UseDefaultCollections"))
    }
    
    var body: some View {
        // Default Collections Toggle Section
        Section {
            Toggle("Use Default", isOn: $useDefault)
                .onChange(of: useDefault) { newValue in
                    // Directly save to UserDefaults first
                    UserDefaults.standard.set(newValue, forKey: "UseDefaultCollections")
                    UserDefaults.standard.synchronize() // Force immediate write
                    
                    // Update the viewModel
                    viewModel.useDefaultCollections = newValue
                    
                    logger.debug("Use Default toggled to \(newValue), saved to UserDefaults")
                }
        } header: {
            Text("Home Feed")
        } footer: {
            if viewModel.useDefaultCollections {
                Text("The app will automatically prioritize preferred collections for better content quality.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        
        // Feed Presets Section
        Section {
            ForEach(viewModel.presets) { preset in
                // Simple row for unselected presets - just shows name, tapping selects it
                if !preset.isSelected {
                    HStack {
                        Text(preset.name)
                            .foregroundColor(useDefault ? .gray : .primary)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !useDefault {
                            viewModel.selectPreset(withId: preset.id)
                        }
                    }
                } 
                // Navigation link for selected preset - shows name, checkmark, and caret
                else {
                    NavigationLink(destination: PresetDetailView(viewModel: viewModel, preset: preset)) {
                        HStack {
                            Text(preset.name)
                                .foregroundColor(useDefault ? .gray : .primary)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(useDefault ? .gray : .blue)
                        }
                    }
                    .disabled(useDefault)
                }
            }
            
            // Add New Preset row
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(useDefault ? .gray : .blue)
                Text("Add New Preset")
                    .foregroundColor(useDefault ? .gray : .primary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if !useDefault {
                    showingNewPresetAlert = true
                    newPresetName = ""
                }
            }
            .disabled(useDefault)
        } header: {
            Text("Feed Presets")
        } footer: {
            Text("When custom settings are used, videos are selected from your enabled collections or saved identifiers.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .disabled(useDefault)
        .opacity(useDefault ? 0.6 : 1.0)
        .onAppear {
            // Read the value from UserDefaults to stay in sync
            useDefault = UserDefaults.standard.bool(forKey: "UseDefaultCollections")
            // Ensure viewModel is in sync
            viewModel.useDefaultCollections = useDefault
            // Load presets
            viewModel.loadPresets()
            
            logger.debug("On appear - useDefault: \(useDefault), viewModel.useDefaultCollections: \(viewModel.useDefaultCollections)")
        }
        .alert("New Preset", isPresented: $showingNewPresetAlert) {
            TextField("Preset Name", text: $newPresetName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                if !newPresetName.isEmpty {
                    viewModel.createNewPreset(name: newPresetName)
                }
            }
        } message: {
            Text("Enter a name for your new preset:")
        }
    }
}