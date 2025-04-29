import SwiftUI

struct SimilarFeedView: View {
    @ObservedObject var viewModel: SimilarFeedViewModel
    @State private var showingPlayer = false
    @State private var selectedViewModel: SearchViewModel?
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.items.isEmpty {
                LoadingView()
            } else if viewModel.errorMessage != nil && viewModel.items.isEmpty {
                ErrorView(error: viewModel.errorMessage ?? "Unknown error") {
                    Task {
                        await viewModel.loadInitialItems()
                    }
                }
            } else if viewModel.items.isEmpty {
                EmptyView(message: "No similar videos found")
            } else {
                List {
                    ForEach(viewModel.items) { item in
                        FeedItemCell(item: item)
                            .onTapGesture {
                                viewModel.selectItem(item)
                            }
                            .listRowBackground(Color.black)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Similar Videos")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showingPlayer) {
            if let viewModel = selectedViewModel {
                SwipeablePlayerView(
                    provider: viewModel,
                    isPresented: $showingPlayer
                )
                .onAppear {
                    // Start playback when view appears
                    viewModel.resumePlayback()
                }
                .onDisappear {
                    // Cleanup when view disappears
                    viewModel.pausePlayback()
                    viewModel.cleanup()
                }
            }
        }
        .onChange(of: viewModel.selectedItem) { _, item in
            if let item = item {
                // Create a SearchViewModel to handle playing the video
                let searchViewModel = SearchViewModel(
                    searchManager: SearchManager(),
                    videoLoadingService: VideoLoadingService(
                        archiveService: ArchiveService(),
                        cacheManager: VideoCacheManager()
                    ),
                    favoritesManager: FavoritesManager()
                )
                
                // Prepare the view model with the selected item
                Task {
                    // Set the search result directly
                    searchViewModel.searchQuery = "Similar to " + (item.title.prefix(20) + "...")
                    searchViewModel.currentResult = item.searchResult
                    selectedViewModel = searchViewModel
                    showingPlayer = true
                }
            }
        }
    }
}

// Simple empty view for consistent UI
struct EmptyView: View {
    var message: String
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "rectangle.stack")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text(message)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding()
    }
}