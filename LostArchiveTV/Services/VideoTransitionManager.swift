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

class VideoTransitionManager: ObservableObject {
    // State tracking
    @Published var isTransitioning = false

    // Preload manager handles all the preloading logic
    internal let preloadManager = TransitionPreloadManager()

    // Flag to track if preloading is paused
    internal var isPreloadingPaused = false
    
    // Direction for swiping
    enum SwipeDirection {
        case up    // Swiping up shows next video
        case down  // Swiping down shows previous video
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

    var prevVideoReady: Bool { preloadManager.prevVideoReady }
    var prevPlayer: AVPlayer? { preloadManager.prevPlayer }
    var prevTitle: String { preloadManager.prevTitle }
    var prevCollection: String { preloadManager.prevCollection }
    var prevDescription: String { preloadManager.prevDescription }
    var prevIdentifier: String { preloadManager.prevIdentifier }
    var prevFilename: String { preloadManager.prevFilename }
    var prevTotalFiles: Int { preloadManager.prevTotalFiles }
    
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