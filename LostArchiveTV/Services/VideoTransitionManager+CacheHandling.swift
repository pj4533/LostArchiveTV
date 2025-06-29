//
//  VideoTransitionManager+CacheHandling.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 5/31/25.
//

import Foundation
import OSLog

// MARK: - Cache Handling
extension VideoTransitionManager {
    func handlePostTransitionCaching(provider: VideoProvider, direction: SwipeDirection) async {
        Logger.caching.info("📢 TRANSITION COMPLETE: Starting cache advancement after \(direction == .up ? "UP" : "DOWN") transition")
        Logger.preloading.notice("🅰️ TRANSITION HANDLER: handlePostTransitionCaching called for \(direction == .up ? "UP" : "DOWN") transition")

        // CRITICAL: Reset the preloading indicator since we're starting fresh preloads
        await MainActor.run {
            PreloadingIndicatorManager.shared.reset()
            Logger.caching.info("🔄 TRANSITION: Reset preloading indicator for new video")
        }

        // Create a cached video from the current preloaded video first
        if let cacheableProvider = provider as? CacheableProvider {
            // CRITICAL: Signal that preloading is starting BEFORE we modify the cache
            // This ensures NO caching operations interfere with preloading
            Logger.preloading.notice("🅱️ TRANSITION HANDLER: About to call setPreloadingStarted()")
            await cacheableProvider.cacheService.setPreloadingStarted()
            Logger.caching.info("🚦 TRANSITION: Signaled preloading started to halt caching BEFORE cache operations")

            // Get cache state before any operations
            let cacheCount = await cacheableProvider.cacheManager.cacheCount()
            Logger.caching.info("📊 TRANSITION: Initial cache count: \(cacheCount)")

            // This is the key part - ensure the current video is in the cache
            // since it was previously outside the cache as a preloaded video
            if let currentVideo = await provider.createCachedVideoFromCurrentState() {
                Logger.caching.info("🧹 TRANSITION: Removing current video from cache if it exists: \(currentVideo.identifier)")
                await cacheableProvider.cacheManager.removeVideo(identifier: currentVideo.identifier)
            }

            // Skip cache window advancement during transition
            // We'll do this after preloading is complete instead
            Logger.caching.info("🔄 TRANSITION: Skipping cache advancement until preloading completes")
        } else {
            // Fallback for non-cacheable providers
            Logger.caching.info("🔄 TRANSITION: Provider doesn't support sliding window, using regular cache filling")
            await provider.ensureVideosAreCached()
        }

        // Preload the next and previous videos for the UI
        Logger.caching.info("🔄 TRANSITION COMPLETE: Preloading next/previous videos for UI")
        await self.preloadNextVideo(provider: provider)
        await self.preloadPreviousVideo(provider: provider)
        Logger.caching.info("✅ TRANSITION COMPLETE: Done preloading videos for UI")

        // CRITICAL: Reset preloading flags to allow caching to resume
        if let cacheableProvider = provider as? CacheableProvider {
            Logger.caching.info("🔄 TRANSITION CLEANUP: Ensuring preloading flags are reset to allow caching to resume")
            await cacheableProvider.cacheService.setPreloadingComplete()

            // SELECTIVE RESTART: Only trigger caching system if the cache is severely underfilled
            Task {
                try? await Task.sleep(for: .seconds(0.5))

                // Check the current cache state
                let currentCacheCount = await cacheableProvider.cacheManager.cacheCount()
                let maxCacheSize = await cacheableProvider.cacheManager.getMaxCacheSize()

                // Only restart caching if cache is less than half full - this prevents constant emptying/refilling
                if currentCacheCount < (maxCacheSize / 2) {
                    Logger.caching.info("🔄 SELECTIVE RESTART: Cache is severely underfilled (\(currentCacheCount)/\(maxCacheSize)), restarting cache system")
                    await cacheableProvider.cacheService.ensureVideosAreCached(
                        cacheManager: cacheableProvider.cacheManager,
                        archiveService: cacheableProvider.archiveService,
                        identifiers: cacheableProvider.getIdentifiersForGeneralCaching()
                    )
                } else {
                    Logger.caching.info("✅ SKIP RESTART: Cache is already sufficiently filled (\(currentCacheCount)/\(maxCacheSize)), no need to restart")
                }
            }
        }
    }
}