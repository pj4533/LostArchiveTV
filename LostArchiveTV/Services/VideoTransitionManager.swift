//
//  VideoTransitionManager.swift
//  LostArchiveTV
//
//  Created by Claude on 4/21/25.
//

import SwiftUI
import AVKit
import OSLog
import Mixpanel
import Combine

class VideoTransitionManager: ObservableObject {
    // State tracking
    @Published var isTransitioning = false

    // Preload manager handles all the preloading logic
    internal let preloadManager = TransitionPreloadManager()

    // Flag to track if preloading is paused
    internal var isPreloadingPaused = false
    
    // Store for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // Logger for content errors
    private let logger = Logger(subsystem: "com.lostarchive.tv", category: "ContentErrors")
    
    // Direction for swiping
    enum SwipeDirection {
        case up    // Swiping up shows next video
        case down  // Swiping down shows previous video
    }
    
    // MARK: - Initialization
    
    init() {
        setupErrorHandling()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Error Handling
    
    private func setupErrorHandling() {
        // Subscribe to unrecoverable content error notifications
        NotificationCenter.default.publisher(for: .playerEncounteredUnrecoverableError)
            .sink { [weak self] notification in
                guard let self = self else { return }
                
                // Extract error information from notification
                let error = notification.userInfo?["error"] as? Error
                let url = notification.userInfo?["url"] as? URL
                
                self.logger.info("🚫 TRANSITION_MANAGER: Received unrecoverable content error notification")
                if let error = error {
                    self.logger.debug("🚫 TRANSITION_MANAGER: Error: \(error.localizedDescription)")
                }
                if let url = url {
                    self.logger.debug("🚫 TRANSITION_MANAGER: URL: \(url.absoluteString)")
                }
                
                // Handle the error by seamlessly skipping to next video
                self.handleContentError()
            }
            .store(in: &cancellables)
    }
    
    private func handleContentError() {
        // Don't proceed if we're already transitioning
        guard !isTransitioning else {
            logger.debug("⏭️ TRANSITION_MANAGER: Already transitioning, ignoring content error")
            return
        }
        
        // Check if next video is ready
        guard nextVideoReady, nextPlayer != nil else {
            logger.warning("⚠️ TRANSITION_MANAGER: Cannot skip to next video - not ready")
            return
        }
        
        logger.info("⏭️ TRANSITION_MANAGER: Seamlessly skipping to next video due to content error")
        
        // Mark that we need to perform a seamless transition
        // This will be picked up by the view to trigger the transition
        Task { @MainActor in
            // Post a custom notification that the view can listen to
            NotificationCenter.default.post(
                name: .shouldSkipToNextVideo,
                object: self
            )
        }
    }
    
    // Forward preload manager properties
    var nextVideoReady: Bool { preloadManager.nextVideoReady }
    var nextPlayer: AVPlayer? { preloadManager.nextPlayer }
    var nextTitle: String { preloadManager.nextTitle }
    var nextCollection: String { preloadManager.nextCollection }
    var nextDescription: String { preloadManager.nextDescription }
    var nextIdentifier: String { preloadManager.nextIdentifier }
    var nextFilename: String { preloadManager.nextFilename }
    var nextTotalFiles: Int { preloadManager.nextTotalFiles }
    var nextBufferState: BufferState { preloadManager.currentNextBufferState }

    var prevVideoReady: Bool { preloadManager.prevVideoReady }
    var prevPlayer: AVPlayer? { preloadManager.prevPlayer }
    var prevTitle: String { preloadManager.prevTitle }
    var prevCollection: String { preloadManager.prevCollection }
    var prevDescription: String { preloadManager.prevDescription }
    var prevIdentifier: String { preloadManager.prevIdentifier }
    var prevFilename: String { preloadManager.prevFilename }
    var prevTotalFiles: Int { preloadManager.prevTotalFiles }
    var prevBufferState: BufferState { preloadManager.currentPrevBufferState }
    
    // MARK: - Transition Methods
    
    func completeTransition(
        geometry: GeometryProxy,
        provider: VideoProvider,
        dragOffset: Binding<CGFloat>,
        isDragging: Binding<Bool>,
        animationDuration: Double,
        direction: SwipeDirection = .up
    ) {
        // Add logging of the transition operation
        let directionText = direction == .up ? "UP (next)" : "DOWN (previous)"
        Logger.caching.info("🔄 TRANSITION: Starting \(directionText) transition with provider: \(type(of: provider))")
        
        if let providerVideo = provider.currentIdentifier {
            Logger.caching.info("🎬 TRANSITION: Current video: \(providerVideo)")
        }
        
        // Get cache state during transition
        Task {
            if let cacheProvider = provider as? CacheableProvider {
                let cacheCount = await cacheProvider.cacheManager.cacheCount()
                Logger.caching.info("📊 TRANSITION: Cache size at transition start: \(cacheCount)")
            }
        }
        
        switch direction {
        case .up:
            // Swiping UP to see NEXT video
            completeNextVideoTransition(geometry: geometry, provider: provider, dragOffset: dragOffset, 
                                   isDragging: isDragging, animationDuration: animationDuration)
        case .down:
            // Swiping DOWN to see PREVIOUS video
            completePreviousVideoTransition(geometry: geometry, provider: provider, dragOffset: dragOffset, 
                                 isDragging: isDragging, animationDuration: animationDuration)
        }
    }
    
    // Backward compatibility method for existing code
    func completeTransition(
        geometry: GeometryProxy,
        viewModel: VideoPlayerViewModel,
        dragOffset: Binding<CGFloat>,
        isDragging: Binding<Bool>,
        animationDuration: Double,
        direction: SwipeDirection = .up
    ) {
        completeTransition(
            geometry: geometry,
            provider: viewModel,
            dragOffset: dragOffset,
            isDragging: isDragging,
            animationDuration: animationDuration,
            direction: direction
        )
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let shouldSkipToNextVideo = Notification.Name("shouldSkipToNextVideo")
}