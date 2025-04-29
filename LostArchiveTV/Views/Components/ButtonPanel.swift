import SwiftUI
import OSLog

struct ButtonPanel: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    @Binding var showCollectionConfig: Bool
    let identifier: String?
    let startTrimFlow: () -> Void
    
    var body: some View {
        HStack {
            Spacer() // This pushes the VStack to the right edge
            
            VStack(spacing: 12) {
                // Settings button at the top
                OverlayButton(
                    action: { 
                        // Pause video while settings are open
                        viewModel.pausePlayback()
                        showCollectionConfig = true 
                    },
                    disabled: false
                ) {
                    Image(systemName: "gearshape.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22, height: 22)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                }
                
                Spacer()
                
                // Favorite button - above the rewind button
                OverlayButton(
                    action: {
                        viewModel.toggleFavorite()
                        // Add haptic feedback
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    },
                    disabled: viewModel.currentCachedVideo == nil
                ) {
                    Image(systemName: viewModel.isFavorite ? "heart.fill" : "heart")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22, height: 22)
                        .foregroundColor(viewModel.isFavorite ? .red : .white)
                        .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                }
                
                // Restart video button
                OverlayButton(
                    action: {
                        viewModel.restartVideo()
                    },
                    disabled: viewModel.currentVideoURL == nil
                ) {
                    Image(systemName: "backward.end")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                }
                
                // Similar videos button
                OverlayButton(
                    action: {
                        // Pause playback before navigating
                        viewModel.pausePlayback()
                        // Navigate to similar videos if a video exists
                        if let identifier = viewModel.currentCachedVideo?.identifier {
                            NotificationCenter.default.post(
                                name: .showSimilarVideos,
                                object: nil,
                                userInfo: ["identifier": identifier]
                            )
                        }
                    },
                    disabled: viewModel.currentCachedVideo == nil
                ) {
                    Image(systemName: "rectangle.stack")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22, height: 22)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                }
                
                // Trim button - starts download flow first
                OverlayButton(
                    action: startTrimFlow,
                    disabled: viewModel.currentVideoURL == nil
                ) {
                    Image(systemName: "selection.pin.in.out")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22, height: 22)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                }
                
                // Download button with progress indicator
                VideoDownloadButton(
                    downloadViewModel: viewModel.downloadViewModel,
                    provider: viewModel,
                    disabled: viewModel.currentCachedVideo == nil
                )
                
                // Archive.org link button
                ArchiveButton(identifier: identifier)
            }
            .padding(.trailing, 8)
        }
        .sheet(isPresented: $showCollectionConfig) {
            // Resume playback when the sheet is dismissed
            viewModel.resumePlayback()
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
