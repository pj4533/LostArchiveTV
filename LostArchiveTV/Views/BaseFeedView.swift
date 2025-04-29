import SwiftUI

struct BaseFeedView<Item: FeedItem, ViewModel: BaseFeedViewModel<Item>>: View {
    @ObservedObject var viewModel: ViewModel
    
    var emptyStateView: AnyView
    
    init(viewModel: ViewModel, emptyStateView: AnyView) {
        self.viewModel = viewModel
        self.emptyStateView = emptyStateView
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.items.isEmpty {
                loadingView
            } else if let error = viewModel.errorMessage {
                errorView(message: error)
            } else if viewModel.items.isEmpty {
                emptyStateView
            } else {
                feedListView
            }
        }
    }
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            Text("Loading...")
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
                    await viewModel.refreshItems()
                }
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
            Spacer()
        }
        .padding()
    }
    
    private var feedListView: some View {
        List {
            ForEach(viewModel.items) { item in
                FeedItemCell(item: item)
                    .onTapGesture {
                        viewModel.selectItem(item)
                    }
                    .listRowBackground(Color.black)
            }
            
            if viewModel.hasMoreItems {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Spacer()
                }
                .listRowBackground(Color.black)
                .onAppear {
                    Task {
                        await viewModel.loadMoreItems()
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.refreshItems()
        }
    }
}