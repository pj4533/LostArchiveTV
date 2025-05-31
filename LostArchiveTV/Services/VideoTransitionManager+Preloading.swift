//
//  VideoTransitionManager+Preloading.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 5/31/25.
//

import Foundation
import OSLog

// MARK: - Preloading Methods
extension VideoTransitionManager {
    func preloadNextVideo(provider: VideoProvider) async {
        // Skip if preloading is paused
        guard !isPreloadingPaused else {
            Logger.caching.info("⏸️ SKIPPED: preloadNextVideo called while preloading is paused")
            return
        }

        await preloadManager.preloadNextVideo(provider: provider)
    }

    func preloadPreviousVideo(provider: VideoProvider) async {
        // Skip if preloading is paused
        guard !isPreloadingPaused else {
            Logger.caching.info("⏸️ SKIPPED: preloadPreviousVideo called while preloading is paused")
            return
        }

        await preloadManager.preloadPreviousVideo(provider: provider)
    }
    
    /// Ensures that both general video caching and transition-specific caching are performed
    /// - Parameter provider: The video provider that supplies videos
    func ensureAllVideosCached(provider: VideoProvider) async {
        // Skip if preloading is paused
        guard !isPreloadingPaused else {
            Logger.caching.info("⏸️ SKIPPED: ensureAllVideosCached called while preloading is paused")
            return
        }

        // Delegate to the underlying preload manager for unified caching
        await preloadManager.ensureAllVideosCached(provider: provider)
    }

    /// Pauses all preloading and caching operations
    func pausePreloading() {
        Logger.caching.info("⏸️ PAUSE: Pausing all transition preloading operations")
        isPreloadingPaused = true
    }

    /// Resumes all preloading and caching operations
    func resumePreloading() {
        Logger.caching.info("▶️ RESUME: Resuming all transition preloading operations")
        isPreloadingPaused = false
    }

    /// Disables transition manager during trim mode
    func disableForTrimming() {
        Logger.caching.info("⏸️ TRIM: Disabling VideoTransitionManager for trim mode")
        pausePreloading()
    }

    /// Restores transition manager after trim mode
    func enableAfterTrimming() {
        Logger.caching.info("▶️ TRIM: Re-enabling VideoTransitionManager after trim mode")
        resumePreloading()
    }
}