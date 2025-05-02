//
//  FavoritesViewModel+CacheManagement.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import SwiftUI
import AVKit
import AVFoundation
import OSLog

// MARK: - Cache Management
extension FavoritesViewModel {
    func ensureVideosAreCached() async {
        Logger.caching.info("FavoritesViewModel.ensureVideosAreCached: Preparing videos for swipe navigation")
        
        // If we have a reference to the transition manager, use it directly
        if let transitionManager = transitionManager {
            Logger.caching.info("Using transition manager for direct preloading")
            
            // Preload in both directions using the transition manager (which sets the ready flags)
            async let nextTask = transitionManager.preloadNextVideo(provider: self)
            async let prevTask = transitionManager.preloadPreviousVideo(provider: self)
            
            // Wait for both preloads to complete
            _ = await (nextTask, prevTask)
            
            // Log the results
            Logger.caching.info("Direct preloading complete - nextVideoReady: \(transitionManager.nextVideoReady), prevVideoReady: \(transitionManager.prevVideoReady)")
        } else {
            Logger.caching.error("⚠️ No transition manager available for preloading")
            
            // Fallback: just get the videos without setting up players
            async let nextTask = Task {
                await getNextVideo()
            }
            
            async let prevTask = Task {
                await getPreviousVideo()
            }
            
            // Wait for both tasks to complete
            _ = await [nextTask.value, prevTask.value]
        }
    }
}