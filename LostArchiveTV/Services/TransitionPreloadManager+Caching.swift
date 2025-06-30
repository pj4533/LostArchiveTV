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

// Timeout utility to prevent hanging preloading operations
extension Task where Success == Never, Failure == Never {
    static func timeout(seconds: Double) async throws {
        try await Task.sleep(for: .seconds(seconds))
        throw TimeoutError()
    }
}

struct TimeoutError: Error {}

extension TransitionPreloadManager {
    // Timeout wrapper function
    private func withTimeout<T>(timeout seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task<Never, Never>.timeout(seconds: seconds)
                throw TimeoutError()
            }

            // Return the first result, or throw if all tasks failed
            let result = try await group.next()

            // Cancel the remaining task
            group.cancelAll()

            // If we got a result, return it
            return result!
        }
    }
    /// Ensures that both general video caching and transition-specific caching are performed
    /// - Parameter provider: The video provider that supplies videos
    func ensureAllVideosCached(provider: VideoProvider) async {
        // Store weak reference to provider for buffer state queries
        if let baseProvider = provider as? BaseVideoViewModel {
            self.provider = baseProvider
        }
        
        // Include timestamp for better tracking of operations
        let startTime = CFAbsoluteTimeGetCurrent()
        Logger.caching.info("🔄 CACHING: Starting unified caching for \(String(describing: type(of: provider))) at \(startTime)")
        Logger.preloading.notice("🅲️ ENSURE ALL: ensureAllVideosCached called on TransitionPreloadManager")

        // Only proceed with caching if we have a cacheable provider
        guard let cacheableProvider = provider as? CacheableProvider else {
            Logger.caching.info("⚠️ CACHING: Provider does not support general caching")

            // Even for non-cacheable providers, always preload for swiping
            Logger.caching.info("🔄 CACHING: Preloading transition videos for non-cacheable provider")

            // Use the same task group pattern for non-cacheable providers
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    await self.preloadNextVideo(provider: provider)
                }
                group.addTask {
                    await self.preloadPreviousVideo(provider: provider)
                }

                await group.waitForAll()
            }

            return
        }

        // PHASE 1: Preload videos for immediate swiping
        // This is the highest priority task - must complete before ANY caching begins
        Logger.caching.info("🔄 PHASE 1: Prioritizing next/previous videos for immediate swiping")

        // Cancel any existing caching task to ensure resources for preloading
        await cacheableProvider.cacheService.cancelCaching()

        // Create a separate task group to ensure preloading completes fully before continuing
        do {
            try await withTimeout(timeout: 10.0) {
                await withTaskGroup(of: Void.self) { group in
                    // Add preload tasks to the group
                    group.addTask {
                        await self.preloadNextVideo(provider: provider)
                    }
                    group.addTask {
                        await self.preloadPreviousVideo(provider: provider)
                    }

                    // Wait for all preloading tasks to complete before proceeding
                    await group.waitForAll()
                }
            }
        } catch {
            Logger.caching.warning("⚠️ TIMEOUT: Preloading tasks timed out after 10 seconds")

            // If preloading times out, ensure we don't leave the system in a blocked state
            if let cacheableProvider = provider as? CacheableProvider {
                Logger.caching.info("🔄 TIMEOUT RECOVERY: Ensuring preloading flags are reset due to timeout")
                await cacheableProvider.cacheService.setPreloadingComplete()
            }
        }

        // Introduce a small delay to ensure any pending state updates are processed
        try? await Task.sleep(for: .seconds(0.1))

        Logger.caching.info("✅ PHASE 1 COMPLETE: Preloading functions have returned, but buffer may still be loading")
        Logger.caching.info("  → Current status: nextVideoReady: \(self.nextVideoReady), prevVideoReady: \(self.prevVideoReady)")

        // Only proceed to phase 2 if we have identifiers to cache
        let identifiers = cacheableProvider.getIdentifiersForGeneralCaching()

        if identifiers.isEmpty {
            Logger.caching.warning("⚠️ CACHING: Provider returned no identifiers for general caching")
            return
        }

        // Create a dedicated task that will wait until both next AND prev videos are ready
        Logger.caching.info("⏸️ PHASE 2 DELAYED: Waiting for video buffers to be fully ready before starting cache")

        // Store the Phase 2 task so we can await it if needed
        // This task will monitor Phase 1 completion before starting any Phase 2 caching
        let phase2Task = Task {
            // CRITICAL: First wait for Phase 1 preloading to actually complete
            // Monitor ready flags in a loop with backoff
            var attempt = 0
            let maxAttempts = 60 // Up to 30 seconds with backoff
            var waitTime = 0.1 // Start with 100ms

            // Wait for either preload flag to be true
            while attempt < maxAttempts {
                attempt += 1

                // Check both ready flags - only proceed when at least one is ready
                // (prev may be nil if there's no history)
                if self.nextVideoReady || self.prevVideoReady {
                    Logger.caching.info("✅ PRELOADING COMPLETE: At least one transition direction is fully ready")
                    Logger.caching.info("  → nextVideoReady = \(self.nextVideoReady), prevVideoReady = \(self.prevVideoReady)")

                    // CRITICAL: Signal to VideoCacheService that preloading is complete
                    // This will allow caching to proceed
                    await cacheableProvider.cacheService.setPreloadingComplete()

                    break
                }

                // Not ready yet, log and wait with backoff
                Logger.caching.info("⏳ STILL WAITING: Videos not fully buffered yet (Attempt \(attempt)/\(maxAttempts))")
                Logger.caching.info("  → nextVideoReady = \(self.nextVideoReady), prevVideoReady = \(self.prevVideoReady)")

                // Wait with exponential backoff up to 2s
                try? await Task.sleep(for: .seconds(min(waitTime, 2.0)))
                waitTime *= 1.5 // Exponential backoff

                // Check for task cancellation
                if Task.isCancelled {
                    Logger.caching.info("🛑 WAIT TASK CANCELLED: Abandoning cache start")
                    return
                }
            }

            // Either we're ready or we timed out - log appropriately
            if !(self.nextVideoReady || self.prevVideoReady) {
                Logger.caching.warning("⚠️ TIMED OUT: Max wait time reached - preloaded videos still not ready. Starting cache anyway")

                // Even if we timed out, we need to signal completion to allow caching to proceed
                await cacheableProvider.cacheService.setPreloadingComplete()
            }

            // IMPORTANT: Add a delay after Phase 1 completion to ensure videos are fully processed
            // This prevents Phase 2 from immediately starting to load new videos
            Logger.caching.info("⏳ PHASE 2 DELAY: Waiting 1 second to ensure Phase 1 videos are fully processed")
            try? await Task.sleep(for: .seconds(1.0))

            // Now check if we should proceed with Phase 2 caching
            let cacheManager = cacheableProvider.cacheManager
            let currentCacheCount = await cacheManager.cacheCount()
            let maxCacheSize = await cacheManager.getMaxCacheSize()

            Logger.caching.info("📊 CACHE STATUS: Current size after Phase 1: \(currentCacheCount)/\(maxCacheSize)")

            // If cache is already full or nearly full (accounting for preloaded videos), skip phase 2
            if currentCacheCount >= maxCacheSize - 2 {  // Account for next/prev videos
                Logger.caching.info("📊 CACHING: Cache is sufficiently full after Phase 1, skipping general cache filling")
                
                // Still advance the cache window to maintain proper positioning
                Logger.caching.info("🔄 CACHE WINDOW: Advancing cache window without additional caching")
                await cacheableProvider.cacheManager.advanceCacheWindow(
                    archiveService: cacheableProvider.archiveService,
                    identifiers: cacheableProvider.getIdentifiersForGeneralCaching()
                )
                
                return
            }

            // Now we can finally begin the actual caching process
            Logger.caching.info("🔄 PHASE 2: Starting general cache filling with \(identifiers.count) identifiers")
            Logger.caching.info("🔄 CACHING: Need to add \(maxCacheSize - currentCacheCount) videos to reach full cache")

            // First advance the cache window
            Logger.caching.info("🔄 CACHE WINDOW: Advancing cache window before general caching")
            await cacheableProvider.cacheManager.advanceCacheWindow(
                archiveService: cacheableProvider.archiveService,
                identifiers: cacheableProvider.getIdentifiersForGeneralCaching()
            )

            // Then start the general caching
            if provider is VideoPlayerViewModel {
                // For the main player, use VideoCacheService
                Logger.caching.info("🔄 CACHING: Starting general cache filling via VideoCacheService")
                await cacheableProvider.cacheService.ensureVideosAreCached(
                    cacheManager: cacheableProvider.cacheManager,
                    archiveService: cacheableProvider.archiveService,
                    identifiers: identifiers
                )
            } else {
                // For other providers (Favorites, Search), use VideoCacheManager directly
                Logger.caching.info("🔄 CACHING: Using VideoCacheManager directly for \(String(describing: type(of: provider)))")
                await cacheableProvider.cacheManager.ensureVideosAreCached(
                    identifiers: identifiers,
                    using: cacheableProvider.archiveService
                )
            }
        }
        
        // Store the task reference for potential cancellation
        self.phase2CachingTask = phase2Task

        Logger.caching.info("✅ CACHING: ensureAllVideosCached complete - cache filling will start in background after preloading is done")
    }
}