import SwiftUI
import OSLog

struct SimilarView: View {
    // Reference the main SearchFeedViewModel from ContentView
    @StateObject private var viewModel: SearchFeedViewModel
    
    // Use the shared SearchViewModel from app launch instead of creating a new one
    init(referenceIdentifier: String, searchViewModel: SearchViewModel) {
        // Create the feed view model with the SHARED SearchViewModel
        self._viewModel = StateObject(wrappedValue: SearchFeedViewModel(
            searchManager: SearchManager(),
            searchViewModel: searchViewModel
        ))
        
        // Store the reference identifier for loading on appear
        self.referenceIdentifier = referenceIdentifier
    }
    
    private let referenceIdentifier: String
    
    var body: some View {
        VStack {
            // Use the SearchFeedView-style layout but without the search bar
            BaseFeedView(
                viewModel: viewModel,
                emptyStateView: AnyView(emptyStateView)
            )
            .navigationTitle("Similar Videos")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Load similar videos when the view appears
                Task {
                    await loadSimilarVideos()
                }
            }
            .fullScreenCover(isPresented: $viewModel.showingPlayer, onDismiss: {
                // Stop playback when the player is dismissed
                Task {
                    await viewModel.searchViewModel.pausePlayback()
                    viewModel.searchViewModel.player = nil
                }
            }) {
                SwipeablePlayerView(
                    provider: viewModel.searchViewModel,
                    isPresented: $viewModel.showingPlayer
                )
            }
        }
    }
    
    private func loadSimilarVideos() async {
        viewModel.isLoading = true
        
        do {
            // Set the view model to similar search mode
            viewModel.setAsSimilarSearch(forIdentifier: referenceIdentifier)
            
            // Create a search query context specifically for similar videos
            let queryContext = SearchQueryContext(
                similarToIdentifier: referenceIdentifier
            )
            
            // Use SearchManager with the context for proper pagination
            let results = try await SearchManager().search(
                queryContext: queryContext,
                page: 0,  // Start with first page
                pageSize: viewModel.pageSize
            )
            
            // Convert to SearchFeedItems and update the view model
            let items = results.map { SearchFeedItem(searchResult: $0, searchViewModel: viewModel.searchViewModel) }
            viewModel.items = items
            
            // Also update the searchViewModel for player functionality
            viewModel.searchViewModel.searchResults = results
            viewModel.searchViewModel.searchQuery = "Similar to \(referenceIdentifier)"
            
            // Proactively fetch file counts for similar video results
            Task.detached(priority: .background) {
                let prefetchCount = min(10, results.count)
                for i in 0..<prefetchCount {
                    let _ = await viewModel.searchViewModel.fetchFileCount(for: results[i].identifier.identifier)
                    // Small delay to avoid overwhelming the server
                    try? await Task.sleep(for: .milliseconds(100))
                }
            }
            
            // Store the query context for pagination
            viewModel.currentPage = 1  // We've loaded page 0, next will be page 1
            viewModel.hasMoreItems = !results.isEmpty  // If we got results, assume there might be more
            
            // Clear loading state
            viewModel.errorMessage = nil
        } catch {
            // Handle errors
            viewModel.errorMessage = "Failed to load similar videos: \(error.localizedDescription)"
            Logger.network.error("Failed to load similar videos: \(error.localizedDescription)")
        }
        
        viewModel.isLoading = false
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("No similar videos found")
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding()
    }
}
