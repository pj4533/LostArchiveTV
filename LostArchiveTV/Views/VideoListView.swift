import SwiftUI

struct VideoListView: View {
    @StateObject private var viewModel = VideoListViewModel()
    @State private var selectedVideo: ArchiveVideo?
    
    private let columns = [
        GridItem(.adaptive(minimum: 300), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(viewModel.videos) { video in
                        NavigationLink(destination: VideoPlayerView(video: video)) {
                            VideoCard(video: video)
                                .onAppear {
                                    if video.id == viewModel.videos.last?.id {
                                        Task {
                                            await viewModel.loadMoreVideosIfNeeded()
                                        }
                                    }
                                }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                }
                
                if let error = viewModel.error {
                    ErrorView(message: error, retryAction: {
                        Task {
                            await viewModel.loadInitialVideos()
                        }
                    })
                }
            }
            .navigationTitle("Lost Archive TV")
            .task {
                if viewModel.videos.isEmpty {
                    await viewModel.loadInitialVideos()
                }
            }
            .refreshable {
                await viewModel.loadInitialVideos()
            }
        }
    }
}

struct ErrorView: View {
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Something went wrong")
                .font(.headline)
            
            Text(message)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button(action: retryAction) {
                Text("Try Again")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(radius: 2)
        )
        .padding()
    }
}