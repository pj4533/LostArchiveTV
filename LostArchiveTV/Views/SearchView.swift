import SwiftUI
import OSLog

struct SearchView: View {
    @StateObject var viewModel: SearchViewModel
    @State private var showingFilters = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 16) {
                    searchBar
                    
                    if viewModel.isSearching {
                        loadingView
                    } else if let error = viewModel.errorMessage {
                        errorView(message: error)
                    } else if viewModel.searchResults.isEmpty {
                        emptyResultsView
                    } else {
                        searchResultsGrid
                    }
                }
                .navigationTitle("Search")
                .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showingFilters) {
                SearchFilterView(filter: $viewModel.searchFilter)
            }
            .fullScreenCover(isPresented: $viewModel.showingPlayer, onDismiss: {
                // Stop playback when the player is dismissed (gentler approach)
                Task {
                    await viewModel.pausePlayback()
                    viewModel.player = nil
                }
            }) {
                SwipeablePlayerView(provider: viewModel, 
                                   isPresented: $viewModel.showingPlayer)
                .onAppear {
                    // Start preloading videos
                    Task {
                        await viewModel.ensureVideosAreCached()
                    }
                }
            }
        }
        .onDisappear {
            // Clean up when view disappears from navigation
            viewModel.cleanup()
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
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            Text("Searching...")
                .foregroundColor(.white)
                .padding()
            Spacer()
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.yellow)
            Text(message)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task {
                    await viewModel.search()
                }
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
            Spacer()
        }
        .padding()
    }
    
    private var emptyResultsView: some View {
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
    
    private var searchResultsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 160), spacing: 2)
            ], spacing: 2) {
                ForEach(Array(viewModel.searchResults.enumerated()), id: \.element.id) { index, result in
                    SearchResultCell(result: result, index: index, viewModel: viewModel)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

struct SearchResultCell: View {
    let result: SearchResult
    let index: Int
    let viewModel: SearchViewModel
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Image placeholder or actual thumbnail
            AsyncImage(url: URL(string: "https://archive.org/services/img/\(result.identifier.identifier)")) { phase in
                if let image = phase.image {
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                } else if phase.error != nil {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "photo.fill")
                                .foregroundColor(.gray)
                        )
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        )
                }
            }
            .aspectRatio(1, contentMode: .fill)
            
            // Title overlay at bottom
            VStack(alignment: .leading) {
                Spacer()
                Text(result.title)
                    .lineLimit(2)
                    .font(.caption)
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.black.opacity(0.7))
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 160)
        .clipped()
        .onTapGesture {
            viewModel.playVideoAt(index: index)
        }
    }
}