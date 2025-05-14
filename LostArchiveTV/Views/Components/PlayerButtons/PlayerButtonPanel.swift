import SwiftUI

struct PlayerButtonPanel<Provider: VideoControlProvider>: View {
    @ObservedObject var provider: Provider
    var showSettingsButton: Bool = true
    var settingsAction: (() -> Void)? = nil
    var backAction: (() -> Void)? = nil
    var trimAction: (() -> Void)
    var identifier: String?
    
    var body: some View {
        HStack {
            Spacer() // This pushes the VStack to the right edge
            
            VStack(spacing: 12) {
                // Top button - either Settings or placeholder
                if showSettingsButton, let settingsAction = settingsAction {
                    SettingsButton(
                        action: {
                            Task {
                                await provider.pausePlayback()
                                settingsAction()
                            }
                        },
                        disabled: false
                    )
                } else {
                    // Empty space for layout consistency
                    Color.clear
                        .frame(width: 22, height: 22)
                }
                
                Spacer()
                
                // Favorite button
                FavoriteButton(
                    isFavorite: provider.isFavorite,
                    action: { provider.toggleFavorite() },
                    disabled: provider.currentIdentifier == nil
                )

                // Save identifier button
                SaveIdentifierButton(
                    action: {
                        Task {
                            await provider.saveIdentifier()
                        }
                    },
                    disabled: provider.currentIdentifier == nil
                )
                
                // Restart video button
                RestartButton(
                    action: { provider.restartVideo() },
                    disabled: provider.player == nil
                )
                
                // Similar videos button
                SimilarButton(
                    action: {
                        // Pause playback before navigating
                        Task {
                            await provider.pausePlayback()
                            // Navigate to similar videos if an identifier exists
                            if let identifier = provider.currentIdentifier {
                                NotificationCenter.default.post(
                                    name: .showSimilarVideos,
                                    object: nil,
                                    userInfo: ["identifier": identifier]
                                )
                            }
                        }
                    },
                    disabled: provider.currentIdentifier == nil
                )
                
                // Trim button
                TrimButton(
                    action: {
                        Task {
                            await provider.pausePlayback()
                            trimAction()
                        }
                    },
                    disabled: provider.currentIdentifier == nil
                )
                
                // Download button with progress indicator
                VideoDownloadButton(
                    downloadViewModel: provider.downloadViewModel,
                    provider: provider,
                    disabled: provider.currentIdentifier == nil
                )
                
                // Archive.org link button
                ArchiveButton(identifier: identifier ?? provider.currentIdentifier)
            }
            .padding(.trailing, 8)
        }
    }
}