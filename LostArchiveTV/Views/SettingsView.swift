import SwiftUI
import OSLog

// Required for DatabaseService
import Foundation
import SQLite3

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var homeFeedViewModel = HomeFeedSettingsViewModel(databaseService: DatabaseService.shared)
    
    var body: some View {
        NavigationView {
            List {
                // Home Feed Settings section
                HomeFeedSettingsSection(viewModel: homeFeedViewModel)
                                
                // Playback settings section
                Section(header: Text("Playback")) {
                    HStack(spacing: 12) {
                        Image(systemName: "play.circle")
                            .foregroundColor(.blue)
                            .frame(width: 28, height: 28)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        
                        Toggle("Start Videos at Beginning", isOn: Binding(
                            get: {
                                PlaybackPreferences.alwaysStartAtBeginning
                            },
                            set: { newValue in
                                PlaybackPreferences.alwaysStartAtBeginning = newValue
                            }
                        ))
                    }
                    .padding(.vertical, 4)
                }
                
                // about should always be at the bottom of the settingsview
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
