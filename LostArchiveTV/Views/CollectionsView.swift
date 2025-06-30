import SwiftUI

struct CollectionsView: View {
    @ObservedObject var viewModel: HomeFeedSettingsViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Collection selection interface
            VStack(spacing: 0) {
                HStack {
                    Button("Select All") {
                        viewModel.selectAll()
                    }
                    
                    Spacer()
                    
                    Text("\(viewModel.collections.filter { $0.isEnabled }.count) selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Deselect All") {
                        viewModel.deselectAll()
                    }
                }
                .padding()
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .padding(.leading, 10)
                    
                    TextField("Search collections", text: $viewModel.searchText)
                        .padding(.vertical, 10)
                    
                    if !viewModel.searchText.isEmpty {
                        Button(action: {
                            viewModel.searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .padding(.trailing, 10)
                        }
                    } else {
                        // Add padding to maintain consistent width
                        Spacer()
                            .frame(width: 30)
                    }
                }
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Loading collections...")
                    Spacer()
                } else if viewModel.filteredCollections.isEmpty {
                    Spacer()
                    Text("No collections found")
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    List {
                        ForEach(viewModel.filteredCollections) { collection in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(collection.name)
                                        .lineLimit(1)
                                    
                                    if collection.isPreferred {
                                        Text("Preferred")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: Binding(
                                    get: { collection.isEnabled },
                                    set: { _ in 
                                        viewModel.toggleCollection(collection.id)
                                    }
                                ))
                                .labelsHidden()
                            }
                            .frame(minHeight: 44)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
        }
        .navigationTitle("Collections")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            // Sync collections with the currently selected preset
            // This ensures UI reflects correct state when navigating here
            viewModel.syncCollectionsWithSelectedPreset()
        }
    }
}