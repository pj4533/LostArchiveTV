import SwiftUI

struct VideoDownloadButton<Provider>: View where Provider: VideoDownloadable {
    @ObservedObject var downloadViewModel: VideoDownloadViewModel
    let provider: Provider
    let disabled: Bool
    
    var body: some View {
        ProgressOverlayButton(
            action: { 
                if !downloadViewModel.isDownloading {
                    downloadViewModel.downloadVideo(from: provider)
                }
            },
            progress: downloadViewModel.downloadProgress,
            isInProgress: downloadViewModel.isDownloading,
            normalIcon: "square.and.arrow.down.fill"
        )
        .disabled(disabled || downloadViewModel.isDownloading)
        .alert("Video Saved", isPresented: $downloadViewModel.showSaveSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Video has been saved to your photo library.")
        }
        .alert("Error Saving Video", isPresented: Binding<Bool>(
            get: { downloadViewModel.saveError != nil },
            set: { if !$0 { downloadViewModel.saveError = nil } }
        )) {
            Button("OK", role: .cancel) { downloadViewModel.saveError = nil }
        } message: {
            if let error = downloadViewModel.saveError {
                Text(error)
            }
        }
    }
}