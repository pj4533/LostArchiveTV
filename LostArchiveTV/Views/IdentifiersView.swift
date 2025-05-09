import SwiftUI

struct IdentifiersView: View {
    @ObservedObject var viewModel: IdentifiersSettingsViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .padding(.leading, 10)
                
                TextField("Search identifiers", text: $viewModel.searchText)
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
            .padding(.top)
            .padding(.bottom, 8)
            
            if viewModel.filteredIdentifiers.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "nosign")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("No identifiers added")
                        .font(.headline)
                    
                    Text("Press the '+' button while viewing a video to add it to this list.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                Spacer()
            } else {
                List {
                    ForEach(viewModel.filteredIdentifiers) { identifier in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(identifier.title)
                                    .lineLimit(1)
                                    .font(.headline)
                                
                                HStack {
                                    Text(identifier.identifier)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text("\(identifier.fileCount) files")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                viewModel.removeIdentifier(identifier.id)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle("Saved Identifiers")
        .navigationBarTitleDisplayMode(.large)
    }
}