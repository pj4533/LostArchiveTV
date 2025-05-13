import SwiftUI

struct HomeFeedSettingsView: View {
    @ObservedObject var viewModel: HomeFeedSettingsViewModel
    
    init(viewModel: HomeFeedSettingsViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Toggle("Use Default", isOn: $viewModel.useDefaultCollections)
                .padding()
                .onChange(of: viewModel.useDefaultCollections) { _ in
                    viewModel.toggleDefaultCollections()
                }
            
            Divider()
            
            if viewModel.useDefaultCollections {
                // Show explanation when using default collections
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                        .padding(.top, 50)
                    
                    Text("Using Default Home Feed Settings")
                        .font(.headline)
                    
                    Text("The app will automatically prioritize preferred collections for better content quality.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else {
                // Show presets list
                List {
                    Section(header: Text("Feed Presets")) {
                        ForEach(viewModel.presets) { preset in
                            // Selected preset gets NavigationLink for details
                            if preset.isSelected {
                                NavigationLink(destination: PresetDetailView(viewModel: viewModel, preset: preset)) {
                                    HStack {
                                        Text(preset.name)
                                            .fontWeight(.bold)
                                        Spacer()
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                            } else {
                                // Non-selected presets are simple buttons that select when tapped
                                HStack {
                                    Text(preset.name)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.selectPreset(withId: preset.id)
                                }
                            }
                        }
                        
                        Button(action: {
                            viewModel.showingNewPresetAlert = true
                            viewModel.newPresetName = ""
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Add New Preset")
                            }
                        }
                    }
                    
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("How videos are selected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                            
                            Text("When custom settings are used, random videos are selected from either your enabled collections or your saved identifiers with equal weighting.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.bottom, 4)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .onAppear {
                    viewModel.loadPresets()
                }
            }
        }
        .navigationTitle("Home Feed Settings")
        .navigationBarTitleDisplayMode(.large)
        .alert("New Preset", isPresented: $viewModel.showingNewPresetAlert) {
            TextField("Preset Name", text: $viewModel.newPresetName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                if !viewModel.newPresetName.isEmpty {
                    viewModel.createNewPreset(name: viewModel.newPresetName)
                }
            }
        } message: {
            Text("Enter a name for your new preset:")
        }
    }
}