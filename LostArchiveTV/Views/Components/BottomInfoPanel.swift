import SwiftUI
import OSLog

struct BottomInfoPanel: View {
    let title: String?
    let collection: String?
    let description: String?
    let identifier: String?
    let filename: String?
    let currentTime: Double?
    let duration: Double
    let totalFiles: Int?
    let cacheStatuses: [CacheStatus]
    
    // Animation state
    @State private var animationTriggered = false
    @State private var showShimmerEffect = false

    init(title: String?, collection: String?, description: String?, identifier: String?, filename: String? = nil, currentTime: Double?, duration: Double, totalFiles: Int? = nil, cacheStatuses: [CacheStatus] = [.notCached, .notCached, .notCached]) {
        self.title = title
        self.collection = collection
        self.description = description
        self.identifier = identifier
        self.filename = filename
        self.currentTime = currentTime
        self.totalFiles = totalFiles
        self.cacheStatuses = cacheStatuses
        // Ensure duration is valid (not NaN or infinity)
        if duration.isNaN || duration.isInfinite {
            self.duration = 0
        } else {
            self.duration = duration
        }
    }

    var body: some View {
        VStack {
            Spacer()

            // Bottom overlay with title and description
            VStack(alignment: .leading, spacing: 8) {
                // Video metadata (title, collection, description, filename)
                VideoMetadataView(
                    title: title,
                    collection: collection,
                    description: description,
                    identifier: identifier,
                    filename: filename,
                    currentTime: currentTime,
                    duration: duration,
                    totalFiles: totalFiles
                )
                .id(duration) // Force view refresh when duration updates

                // Swipe hint with cache status indicators
                HStack {
                    Spacer()
                    Text("Swipe up for next video")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .shimmerEffect(active: showShimmerEffect)
                        .onAppear {
                            // Log what we're about to display to the user
                            let readyStatus = cacheStatuses.count > 0 && cacheStatuses[0] == .preloaded
                            let statusSymbols = cacheStatuses.map { status -> String in
                                switch status {
                                    case .preloaded: return "●" // solid circle
                                    case .cached: return "○"    // outline
                                    case .notCached: return "▢" // empty box
                                }
                            }
                            let statusDisplay = statusSymbols.joined(separator: " ")

                            Logger.caching.info("🖥️ UI DISPLAY: Cache indicators: [\(statusDisplay)], first indicator ready: \(readyStatus)")
                        }
                    CacheStatusIndicator(cacheStatuses: cacheStatuses)
                    Spacer()
                }
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        // Direct binding to TransitionPreloadManager.nextVideoReady
        .onAppear {
            // Simple solution: Use a flag so animation only happens once per view appearance
            animationTriggered = false
            
            // Get existing state on appear
            if let sharedViewModel = SharedViewModelProvider.shared.videoPlayerViewModel,
               let transitionManager = sharedViewModel.transitionManager,
               transitionManager.nextVideoReady {
                // If already ready when view appears, no animation
                animationTriggered = true
            }
        }
        // Watch for changes to CacheStatusChanged notification
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CacheStatusChanged"))) { _ in
            // Direct simple check when notification is received
            if !animationTriggered,  // Only if animation hasn't been triggered yet
               let sharedViewModel = SharedViewModelProvider.shared.videoPlayerViewModel,
               let transitionManager = sharedViewModel.transitionManager,
               transitionManager.nextVideoReady {  // Direct check of the flag
                
                Logger.ui.notice("🎉 Triggering one-time shimmer for next video")
                animationTriggered = true  // Set flag so it only happens once
                
                // Show animation
                showShimmerEffect = true
                
                // Remove after completion
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showShimmerEffect = false
                }
            }
        }
    }
}