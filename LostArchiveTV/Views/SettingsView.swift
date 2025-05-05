import SwiftUI
import OSLog

// Required for DatabaseService
import Foundation
import SQLite3

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Content")) {
                    // Collection settings navigation link
                    NavigationLink(destination: 
                        CollectionConfigView(
                            viewModel: CollectionConfigViewModel(databaseService: DatabaseService())
                        )
                    ) {
                        HStack(spacing: 12) {
                            Image(systemName: "film.stack")
                                .foregroundColor(.blue)
                                .frame(width: 28, height: 28)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            
                            Text("Collection Settings")
                                .font(.system(size: 16))
                                
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // About section with version info (placeholder for now)
                Section(header: Text("About")) {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                            .frame(width: 28, height: 28)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Version")
                                .font(.system(size: 16))
                            
                            Text("\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"))")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                
                // Future sections can go here
                // Section(header: Text("Playback")) { }
                // Section(header: Text("Downloads")) { }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(
                trailing: Button("Close") {
                    dismiss()
                }
            )
        }
    }
}