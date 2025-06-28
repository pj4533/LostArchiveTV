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
    let currentBufferingMonitor: BufferingMonitor?
    let nextBufferingMonitor: BufferingMonitor?
    let nextVideoTitle: String?
    
    // Animation state
    @State private var animationTriggered = false
    @State private var showShimmerEffect = false

    init(title: String?, collection: String?, description: String?, identifier: String?, filename: String? = nil, currentTime: Double?, duration: Double, totalFiles: Int? = nil, currentBufferingMonitor: BufferingMonitor? = nil, nextBufferingMonitor: BufferingMonitor? = nil, nextVideoTitle: String? = nil) {
        self.title = title
        self.collection = collection
        self.description = description
        self.identifier = identifier
        self.filename = filename
        self.currentTime = currentTime
        self.totalFiles = totalFiles
        self.currentBufferingMonitor = currentBufferingMonitor
        self.nextBufferingMonitor = nextBufferingMonitor
        self.nextVideoTitle = nextVideoTitle
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

                // Buffering indicators with swipe hint below
                VStack(spacing: 12) {
                    // Buffering indicators with padding to avoid button overlap
                    if PlaybackPreferences.showBufferIndicators,
                       let currentMonitor = currentBufferingMonitor {
                        BufferingIndicatorView(
                            currentVideoMonitor: currentMonitor,
                            nextVideoMonitor: nextBufferingMonitor,
                            currentVideoTitle: title ?? "Current Video",
                            nextVideoTitle: nextVideoTitle
                        )
                        .padding(.leading, 20) // 20px from left edge
                        .padding(.trailing, 80) // Leave space for right-side buttons
                    }
                    
                    // Swipe hint below indicators - always centered
                    HStack {
                        Spacer()
                        Text("Swipe up for next video")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .shimmerEffect(active: showShimmerEffect)
                            .onAppear {
                                // Log what we're about to display to the user
                                let currentReady = currentBufferingMonitor?.bufferState.isReady ?? false
                                let nextReady = nextBufferingMonitor?.bufferState.isReady ?? false
                                
                                Logger.caching.info("🖥️ UI DISPLAY: Buffering indicators - current ready: \(currentReady), next ready: \(nextReady)")
                            }
                        Spacer()
                    }
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
        // Watch for changes to buffering state
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CacheStatusChanged"))) { _ in
            // Direct simple check when notification is received
            if !animationTriggered,  // Only if animation hasn't been triggered yet
               let nextMonitor = nextBufferingMonitor,
               nextMonitor.bufferState.isReady {  // Check if next video is ready
                
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