import SwiftUI
import OSLog

struct SearchFeedView: View {
    @StateObject var viewModel: SearchFeedViewModel
    @State private var showingFilters = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                searchBar
                
                BaseFeedView(
                    viewModel: viewModel,
                    emptyStateView: AnyView(emptyStateView)
                )
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showingFilters) {
                SearchFilterView(filter: $viewModel.searchFilter)
            }
            .fullScreenCover(isPresented: $viewModel.showingPlayer, onDismiss: {
                // Stop playback when the player is dismissed
                Task {
                    await viewModel.searchViewModel.pausePlayback()
                    viewModel.searchViewModel.player = nil
                }
            }) {
                AppContainer {
                    SwipeablePlayerView(
                        provider: viewModel.searchViewModel,
                        isPresented: $viewModel.showingPlayer
                    )
                }
            }
        }
        .onDisappear {
            // Clean up when view disappears from navigation
            viewModel.searchViewModel.cleanup()
        }
    }
    
    private var searchBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search videos...", text: $viewModel.searchQuery)
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit {
                        Task {
                            await viewModel.search()
                        }
                    }
                
                if !viewModel.searchQuery.isEmpty {
                    Button(action: {
                        viewModel.searchQuery = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(8)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
            
            Button {
                showingFilters.toggle()
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            if viewModel.searchQuery.isEmpty {
                Text("Search for videos from the Internet Archive")
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            } else {
                Text("No results found")
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding()
    }
}