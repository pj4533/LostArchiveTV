import SwiftUI
import OSLog
import Mixpanel

struct ButtonPanel: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    @Binding var showSettings: Bool
    let identifier: String?
    let startTrimFlow: () -> Void
    
    var body: some View {
        // Use the reusable PlayerButtonPanel with VideoPlayerViewModel
        PlayerButtonPanel(
            provider: viewModel,
            showSettingsButton: true,
            settingsAction: { 
                Mixpanel.mainInstance().track(event: "Open Settings")
                showSettings = true 
            },
            trimAction: startTrimFlow,
            identifier: identifier
        )
        .sheet(isPresented: $showSettings) {
            // Resume playback when the sheet is dismissed
            Task {
                await viewModel.resumePlayback()
            }
        } content: {
            SettingsView()
        }
    }
}
