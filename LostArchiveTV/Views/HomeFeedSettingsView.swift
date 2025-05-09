import SwiftUI

struct HomeFeedSettingsView: View {
    @ObservedObject var viewModel: HomeFeedSettingsViewModel
    @StateObject private var identifiersViewModel = IdentifiersSettingsViewModel()
    
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
                // Show NavigationLinks to Collections and Identifiers
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
                    identifiersViewModel.loadIdentifiers()
                }
            }
        }
        .navigationTitle("Home Feed Settings")
        .navigationBarTitleDisplayMode(.large)
    }
}