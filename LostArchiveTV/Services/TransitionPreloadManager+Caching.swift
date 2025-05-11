//
//  TransitionPreloadManager+Caching.swift
//  LostArchiveTV
//
//  Created by Claude on 5/11/25.
//

import SwiftUI
import AVKit
import OSLog
import Foundation

extension TransitionPreloadManager {
    /// Ensures that both general video caching and transition-specific caching are performed
    /// - Parameter provider: The video provider that supplies videos
    func ensureAllVideosCached(provider: VideoProvider) async {
        Logger.caching.info("🔄 CACHING: Starting unified caching for \(String(describing: type(of: provider)))")

        // CRITICAL FIX: First prepare individual videos for swiping to ensure smooth navigation
        // Decoupling the swiping ability from the cache completion state
        Logger.caching.info("🔄 CACHING: Prioritizing transition videos for swipe readiness")
        async let nextTask = preloadNextVideo(provider: provider)
        async let prevTask = preloadPreviousVideo(provider: provider)
        _ = await (nextTask, prevTask)

        Logger.caching.info("✅ CACHING: Transition videos ready - nextVideoReady: \(self.nextVideoReady), prevVideoReady: \(self.prevVideoReady)")

        // Now fill general cache if provider supports it, but don't block swiping on it
        if let cacheableProvider = provider as? CacheableProvider {
            Logger.caching.info("✅ CACHING: Provider supports general caching")
            let identifiers = cacheableProvider.getIdentifiersForGeneralCaching()

            if !identifiers.isEmpty {
                Logger.caching.info("📊 CACHING: Provider returned \(identifiers.count) identifiers for general caching")

                // Check current cache state before caching
                let cacheManager = cacheableProvider.cacheManager
                let initialCacheCount = await cacheManager.cacheCount()
                let maxCacheSize = await cacheManager.getMaxCacheSize()

                Logger.caching.info("📊 CACHING: Current cache size before caching: \(initialCacheCount)/\(maxCacheSize)")

                // Calculate how many videos we need to add to reach the full cache size
                let videosNeeded = maxCacheSize - initialCacheCount

                if videosNeeded > 0 {
                    Logger.caching.info("🔄 CACHING: Need to add \(videosNeeded) videos to reach full cache")

                    if provider is VideoPlayerViewModel {
                        // For the main player, use VideoCacheService which has the most robust implementation
                        Logger.caching.info("🔄 CACHING: Using VideoCacheService for main player with \(identifiers.count) identifiers")
                        await cacheableProvider.cacheService.ensureVideosAreCached(
                            cacheManager: cacheableProvider.cacheManager,
                            archiveService: cacheableProvider.archiveService,
                            identifiers: identifiers
                        )
                    } else {
                        // For other providers (Favorites, Search), use VideoCacheManager directly
                        // This provides more immediate caching for the current view
                        Logger.caching.info("🔄 CACHING: Using VideoCacheManager directly for \(String(describing: type(of: provider)))")
                        await cacheableProvider.cacheManager.ensureVideosAreCached(
                            identifiers: identifiers,
                            using: cacheableProvider.archiveService
                        )
                    }

                    // Check cache after caching
                    let finalCacheCount = await cacheManager.cacheCount()
                    Logger.caching.info("📊 CACHING: Cache size after filling: \(finalCacheCount)/\(maxCacheSize)")
                } else {
                    Logger.caching.info("📊 CACHING: Cache is already full, no need to add more videos")
                }
            } else {
                Logger.caching.warning("⚠️ CACHING: Provider returned no identifiers for general caching")
            }
        } else {
            Logger.caching.info("⚠️ CACHING: Provider does not support general caching")
        }

        Logger.caching.info("✅ CACHING: Unified caching complete")
    }
}