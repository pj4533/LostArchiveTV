import SwiftUI
import OSLog

struct ButtonPanel: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    @Binding var showCollectionConfig: Bool
    let identifier: String?
    let startTrimFlow: () -> Void
    
    var body: some View {
        // Use the reusable PlayerButtonPanel with VideoPlayerViewModel
        PlayerButtonPanel(
            provider: viewModel,
            showSettingsButton: true,
            settingsAction: { 
                showCollectionConfig = true 
            },
            trimAction: startTrimFlow,
            identifier: identifier
        )
        .sheet(isPresented: $showCollectionConfig) {
            // Resume playback when the sheet is dismissed
            Task {
                await viewModel.resumePlayback()
            }
        } content: {
            CollectionConfigView(
                viewModel: CollectionConfigViewModel(databaseService: DatabaseService()),
                onDismiss: { 
                    // Callback when view is dismissed
                    Task {
                        await viewModel.reloadIdentifiers()
                    }
                }
            )
        }
    }
}
