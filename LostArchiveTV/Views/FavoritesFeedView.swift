import SwiftUI
import AVKit

struct FavoritesFeedView: View {
    @ObservedObject var viewModel: FavoritesFeedViewModel
    
    init(viewModel: FavoritesFeedViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        NavigationView {
            BaseFeedView(
                viewModel: viewModel,
                emptyStateView: AnyView(emptyStateView)
            )
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.large)
            .fullScreenCover(isPresented: $viewModel.showPlayer, onDismiss: {
                // Stop playback when the player is dismissed
                Task {
                    await viewModel.favoritesViewModel.pausePlayback()
                    viewModel.favoritesViewModel.player = nil
                }
                // Unregister from preloading indicator
                PreloadingIndicatorManager.shared.unregisterProvider()
            }) {
                AppContainer {
                    SwipeablePlayerView(
                        provider: viewModel.favoritesViewModel, 
                        isPresented: $viewModel.showPlayer
                    )
                    .onAppear {
                        // Register with preloading indicator when showing
                        PreloadingIndicatorManager.shared.registerActiveProvider(viewModel.favoritesViewModel)
                    }
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadInitialItems()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "heart.slash")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("No Favorites Yet")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Add videos to your favorites from the Home tab by tapping the heart icon")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}