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
                // Show NavigationLink to Collections View
                List {
                    NavigationLink(destination: CollectionsView(viewModel: viewModel)) {
                        HStack {
                            Text("Collections")
                            Spacer()
                            Text("\(viewModel.collections.filter { $0.isEnabled }.count) selected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
        }
        .navigationTitle("Home Feed Settings")
        .navigationBarTitleDisplayMode(.large)
    }
}