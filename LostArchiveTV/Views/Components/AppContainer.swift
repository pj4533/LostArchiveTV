import SwiftUI

/// A container view that holds the app content and the preloading indicator
struct AppContainer<Content: View>: View {
    @StateObject private var preloadingIndicatorManager = PreloadingIndicatorManager.shared
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            // Main app content
            content
            
            // Preloading indicator overlay
            RetroEdgePreloadIndicator(state: preloadingIndicatorManager.state)
                .allowsHitTesting(false) // Ensure the indicator doesn't block interaction
        }
    }
}