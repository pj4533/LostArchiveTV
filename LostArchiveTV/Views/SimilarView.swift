import SwiftUI

struct SimilarView: View {
    @StateObject private var viewModel: SimilarFeedViewModel
    
    init(referenceIdentifier: String) {
        _viewModel = StateObject(wrappedValue: SimilarFeedViewModel(referenceIdentifier: referenceIdentifier))
    }
    
    var body: some View {
        SimilarFeedView(viewModel: viewModel)
    }
}