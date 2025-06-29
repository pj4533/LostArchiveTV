//
//  TransitionPreloadManager+NextVideo.swift
//  LostArchiveTV
//
//  Created by Claude on 5/11/25.
//

import SwiftUI
import AVKit
import OSLog
import Foundation

extension TransitionPreloadManager {
    // Preload the next video while current one is playing
    func preloadNextVideo(provider: VideoProvider) async {
        // Log timestamp when preloading starts for performance tracking
        let preloadStartTime = CFAbsoluteTimeGetCurrent()

        Logger.caching.info("🔍 PHASE 1A: Preloading NEXT video for \(String(describing: type(of: provider))) at time \(preloadStartTime)")
        Logger.preloading.notice("🎆 NEXT PRELOAD START: Beginning to preload NEXT video - THIS should trigger the indicator")

        // Signal to the VideoCacheService that preloading has started
        // This will halt ALL caching operations until preloading is complete
        if let cacheableProvider = provider as? CacheableProvider {
            // Explicitly signal preloading has started - this will block ALL caching
            await cacheableProvider.cacheService.setPreloadingStarted()

            let cacheCount = await cacheableProvider.cacheManager.cacheCount()
            let maxCache = await cacheableProvider.cacheManager.getMaxCacheSize()
            Logger.caching.info("⚙️ PRELOAD NEXT: Cache state: \(cacheCount)/\(maxCache) before preloading")
        }

        // Reset next video ready flag
        await MainActor.run {
            nextVideoReady = false
        }
        
        // IMPORTANT: Use peekNextVideo instead of getNextVideo to avoid modifying the history index
        if let nextVideo = await provider.peekNextVideo() {
            Logger.caching.info("🔍 PRELOAD NEXT: Found next video in history: \(nextVideo.identifier)")
            
            // Create a new player with a fresh player item
            let freshPlayerItem = AVPlayerItem(asset: nextVideo.asset)
            let player = AVPlayer(playerItem: freshPlayerItem)
            
            // Prepare player but keep it paused and muted
            player.isMuted = true
            player.pause()
            
            // Seek to the start position
            let startTime = CMTime(seconds: nextVideo.startPosition, preferredTimescale: 600)
            await player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)

            // Update UI on main thread immediately with metadata
            await MainActor.run {
                // Update next video metadata
                nextTitle = nextVideo.title
                nextCollection = nextVideo.collection
                nextDescription = nextVideo.description
                nextIdentifier = nextVideo.identifier
                nextFilename = nextVideo.mp4File.name
                nextTotalFiles = nextVideo.totalFiles
                
                // Store reference to next player
                nextPlayer = player

                Logger.files.info("📊 PRELOAD NEXT: Set nextTotalFiles to \(nextVideo.totalFiles) for \(nextVideo.identifier)")
                Logger.preloading.notice("🎯 NEXT PLAYER: Created player \(String(describing: Unmanaged.passUnretained(player).toOpaque())) for next video")
                
                // CRITICAL: Connect buffer monitors to preloaded players
                if let provider = provider as? BaseVideoViewModel {
                    Logger.preloading.notice("🎯 PRELOAD: Calling updatePreloadMonitors to connect buffer monitor")
                    provider.updatePreloadedBufferingMonitors()
                }
            }
            
            // Delay briefly to ensure monitors are connected before sending signal
            Task {
                try? await Task.sleep(for: .milliseconds(100))
                
                // NOW send the preloading started notification since we're actually preloading a new video
                if let cacheableProvider = provider as? CacheableProvider {
                    Logger.preloading.notice("📢 SIGNAL: Sending preloading started for NEXT video preload (delayed for monitor connection)")
                    await cacheableProvider.cacheService.notifyCachingStarted()
                }
            }
            
            // Start asynchronous buffer monitoring task that will update UI status
            // as soon as the video is actually ready to play
            let videoId = nextVideo.identifier
            let preloadStart = preloadStartTime
            Task {
                // Use the BufferingMonitor's state instead of calculating our own
                if let provider = provider as? BaseVideoViewModel {
                    await monitorNextVideoBufferViaMonitor(provider: provider, videoId: videoId, preloadStart: preloadStart, isRandom: false)
                } else {
                    // Fallback to old method if not BaseVideoViewModel
                    await monitorNextVideoBuffer(player: player, videoId: videoId, preloadStart: preloadStart, isRandom: false)
                }
            }
            
            Logger.caching.info("✅ PRELOAD NEXT: Successfully prepared next video: \(nextVideo.identifier)")

            // Check cache state after preloading to understand relationship to cache
            if let cacheableProvider = provider as? CacheableProvider {
                let cacheCount = await cacheableProvider.cacheManager.cacheCount()
                let maxCache = await cacheableProvider.cacheManager.getMaxCacheSize()
                Logger.caching.info("🔍 PRELOAD NEXT: Cache state AFTER preloading from history: \(cacheCount)/\(maxCache)")

                // Debug: log all cached video identifiers
                let cachedIds = await cacheableProvider.cacheManager.getCachedVideos().map { $0.identifier }
                Logger.caching.info("🔍 PRELOAD NEXT: Cached IDs: \(cachedIds.joined(separator: ", "))")
                Logger.caching.info("🔍 PRELOAD NEXT: Next video ID: \(nextVideo.identifier)")

                // The critical check - is the next video from the cache or separate?
                let isInCache = cachedIds.contains(nextVideo.identifier)
                Logger.caching.info("❓ PRELOAD NEXT: Is next video in cache? \(isInCache)")
            }

            return
        }
        
        // For VideoPlayerViewModel, we can try to load a new random video
        // For FavoritesViewModel, check if we have reached the end
        if let videoPlayerViewModel = provider as? VideoPlayerViewModel {
            // If we don't have a next video in history, get a new random video
            let service = VideoLoadingService(
                archiveService: videoPlayerViewModel.archiveService,
                cacheManager: videoPlayerViewModel.cacheManager
            )
            
            do {
                // Load a complete random video
                let videoInfo = try await service.loadRandomVideo()
                
                // Create a new player for the asset
                let freshPlayerItem = await MainActor.run {
                    AVPlayerItem(asset: videoInfo.asset)
                }
                let player = AVPlayer(playerItem: freshPlayerItem)
                
                // Prepare player but keep it paused and muted
                player.isMuted = true
                player.pause()
                
                // Seek to the start position
                let startTime = CMTime(seconds: videoInfo.startPosition, preferredTimescale: 600)
                await player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)

                // Update UI on main thread immediately with metadata
                await MainActor.run {
                    // Update next video metadata
                    nextTitle = videoInfo.title
                    nextCollection = videoInfo.collection
                    nextDescription = videoInfo.description
                    nextIdentifier = videoInfo.identifier
                    nextFilename = videoInfo.filename

                    // Count total files - temporarily set to 1, we'll update this properly elsewhere
                    nextTotalFiles = 1
                    
                    // Store reference to next player
                    nextPlayer = player

                    Logger.files.info("📊 PRELOAD RAND: Set nextTotalFiles to 1 for \(videoInfo.identifier) (will be updated during transition)")
                }
                
                // Start asynchronous buffer monitoring task that will update UI status
                // as soon as the video is actually ready to play
                let videoId = videoInfo.identifier
                let preloadStart = preloadStartTime
                
                // Start buffer monitoring in background
                Task {
                    // Use the BufferingMonitor's state instead of calculating our own
                    if let provider = provider as? BaseVideoViewModel {
                        await monitorNextVideoBufferViaMonitor(provider: provider, videoId: videoId, preloadStart: preloadStart, isRandom: true)
                    } else {
                        await monitorNextVideoBuffer(player: player, videoId: videoId, preloadStart: preloadStart, isRandom: true)
                    }
                }

                Logger.caching.info("Successfully preloaded new random video: \(videoInfo.identifier)")

                // Check cache state after preloading to understand relationship to cache
                if let cacheableProvider = provider as? CacheableProvider {
                    let cacheCount = await cacheableProvider.cacheManager.cacheCount()
                    let maxCache = await cacheableProvider.cacheManager.getMaxCacheSize()
                    Logger.caching.info("⚠️ PRELOAD NEXT: Cache state AFTER preloading random: \(cacheCount)/\(maxCache) - NEXT VIDEO IS OUTSIDE CACHE!")

                    // Debug: log all cached video identifiers
                    let cachedIds = await cacheableProvider.cacheManager.getCachedVideos().map { $0.identifier }
                    Logger.caching.info("⚠️ PRELOAD NEXT: Cached IDs: \(cachedIds.joined(separator: ", "))")
                    Logger.caching.info("⚠️ PRELOAD NEXT: Next video ID: \(videoInfo.identifier)")
                }
            } catch {
                // Retry on error after a short delay
                Logger.caching.error("Failed to preload random video: \(error.localizedDescription)")
                try? await Task.sleep(for: .seconds(0.5))
                await preloadNextVideo(provider: provider)
            }
        } else if let favoritesViewModel = provider as? FavoritesViewModel {
            // For favorites view, check if we still have favorites in the list
            let favorites = await MainActor.run { favoritesViewModel.favorites }
            let currentIndex = await MainActor.run { favoritesViewModel.currentIndex }
            
            Logger.caching.info("Preloading NEXT for FavoritesViewModel: \(favorites.count) favorites, currentIndex: \(currentIndex)")
            
            // If we have more than one favorite, circularly navigate to enable looping
            if favorites.count > 1 {
                Logger.caching.info("Multiple favorites found (\(favorites.count)), attempting to get next video")
                // We can always loop around in favorites
                if let nextVideo = await provider.getNextVideo() {
                    // Create a new player for the asset
                    let freshPlayerItem = AVPlayerItem(asset: nextVideo.asset)
                    let player = AVPlayer(playerItem: freshPlayerItem)
                    
                    // Prepare player but keep it paused and muted
                    player.isMuted = true
                    player.pause()
                    
                    // Seek to the start position
                    let startTime = CMTime(seconds: nextVideo.startPosition, preferredTimescale: 600)
                    await player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)

                    // Update UI on main thread immediately with metadata
                    await MainActor.run {
                        // Update next video metadata
                        nextTitle = nextVideo.title
                        nextCollection = nextVideo.collection
                        nextDescription = nextVideo.description
                        nextIdentifier = nextVideo.identifier
                        nextFilename = nextVideo.mp4File.name
                        
                        // Store reference to next player
                        nextPlayer = player
                    }
                    
                    // Start asynchronous buffer monitoring task that will update UI status
                    // as soon as the video is actually ready to play
                    let videoId = nextVideo.identifier
                    let preloadStart = preloadStartTime
                    Task {
                        // Use the BufferingMonitor's state instead of calculating our own
                        if let provider = provider as? BaseVideoViewModel {
                            await monitorNextVideoBufferViaMonitor(provider: provider, videoId: videoId, preloadStart: preloadStart, isRandom: false)
                        } else {
                            await monitorNextVideoBuffer(player: player, videoId: videoId, preloadStart: preloadStart, isRandom: false)
                        }
                    }
                    
                    Logger.caching.info("✅ Successfully preloaded next favorite video: \(nextVideo.identifier)")
                } else {
                    Logger.caching.error("❌ Failed to get next video for favorites - returned nil")
                }
            } else {
                // If only one favorite exists, don't enable swiping
                Logger.caching.info("⚠️ Only one favorite video found, not marking as ready")
            }
        } else {
            // Unknown provider type
            Logger.caching.warning("Unknown provider type for preloading")
        }
    }
    
    /// Monitor buffer status using the BufferingMonitor as single source of truth
    private func monitorNextVideoBufferViaMonitor(provider: BaseVideoViewModel, videoId: String, preloadStart: Double, isRandom: Bool = false) async {
        let prefix = isRandom ? "RAND" : "NEXT"
        Logger.caching.info("🔄 PRELOAD \(prefix): Starting buffer monitoring via BufferingMonitor for \(videoId)")
        
        // Give the monitor a moment to stabilize
        try? await Task.sleep(for: .milliseconds(300))
        
        // Wait for the monitor to be ready
        var consecutiveReadyChecks = 0
        while !Task.isCancelled {
            // Get the buffer state from the monitor (single source of truth)
            let bufferState = await MainActor.run {
                provider.nextBufferingMonitor?.bufferState ?? .unknown
            }
            let bufferSeconds = await MainActor.run {
                provider.nextBufferingMonitor?.bufferSeconds ?? 0
            }
            
            Logger.preloading.debug("🎯 MONITOR STATE: Next video buffer from monitor: \(bufferSeconds)s, state=\(bufferState.description)")
            
            // Update buffer state
            await MainActor.run {
                self.updateNextBufferState(bufferState)
            }
            
            // Check if buffer is ready - require 2 consecutive ready states to avoid false positives
            if bufferState.isReady {
                consecutiveReadyChecks += 1
                if consecutiveReadyChecks >= 2 {
                    await MainActor.run {
                        Logger.caching.info("✅ PRELOAD \(prefix): Buffer ready for \(videoId) (buffered: \(bufferSeconds)s, state: \(bufferState.description))")
                        self.nextVideoReady = true
                    }
                    
                    // Calculate and log preloading completion time
                    let preloadEndTime = CFAbsoluteTimeGetCurrent()
                    let preloadDuration = preloadEndTime - preloadStart
                    Logger.caching.info("⏱️ TIMING: \(prefix) video preloading completed in \(preloadDuration.formatted(.number.precision(.fractionLength(3)))) seconds")
                    
                    break
                }
            } else {
                consecutiveReadyChecks = 0
            }
            
            // Wait briefly before checking again
            try? await Task.sleep(for: .seconds(0.5))
        }
    }
    
    /// Monitor buffer status for next video asynchronously
    private func monitorNextVideoBuffer(player: AVPlayer, videoId: String, preloadStart: Double, isRandom: Bool = false) async {
        let prefix = isRandom ? "RAND" : "NEXT"
        Logger.caching.info("🔄 PRELOAD \(prefix): Starting buffer monitoring for \(videoId)")
        Logger.preloading.notice("🔍 MONITOR PLAYER: TransitionPreloadManager monitoring player \(String(describing: Unmanaged.passUnretained(player).toOpaque()))")
        let playerItem = player.currentItem
        
        // Start monitoring buffer status
        while !Task.isCancelled && playerItem == player.currentItem {
            // Get buffer ranges to check actual loaded time
            let loadedTimeRanges = playerItem?.loadedTimeRanges ?? []

            // Calculate buffered duration ahead of current playback position
            var bufferedSeconds = 0.0
            if let currentTime = playerItem?.currentTime(), !loadedTimeRanges.isEmpty {
                // Find how much is buffered ahead of current position
                for range in loadedTimeRanges {
                    let timeRange = range.timeRangeValue
                    let rangeStart = CMTimeGetSeconds(timeRange.start)
                    let rangeEnd = CMTimeGetSeconds(CMTimeAdd(timeRange.start, timeRange.duration))
                    let current = CMTimeGetSeconds(currentTime)
                    
                    // Check if current time is within this range
                    if current >= rangeStart && current <= rangeEnd {
                        // Return the amount buffered ahead
                        bufferedSeconds = rangeEnd - current
                        break
                    }
                    
                    // Check if this range is ahead of current time
                    if rangeStart > current {
                        bufferedSeconds = rangeEnd - current
                        break
                    }
                }
            }

            // Calculate buffer state
            let bufferState = BufferState.from(seconds: bufferedSeconds)
            
            // Log the buffer calculation for debugging
            Logger.preloading.debug("🧮 BUFFER CALC: Next video buffered=\(bufferedSeconds)s, state=\(bufferState.rawValue)")
            
            // Update buffer state
            await MainActor.run {
                self.updateNextBufferState(bufferState)
            }
            
            // Check if buffer is ready - requires both conditions:
            // 1. isPlaybackLikelyToKeepUp is true
            // 2. Buffer state is ready (sufficient, good, or excellent)
            if playerItem?.isPlaybackLikelyToKeepUp == true && bufferState.isReady {
                // Capture values for logging
                let currentBufferedSeconds = bufferedSeconds
                let currentBufferState = bufferState
                
                await MainActor.run {
                    Logger.caching.info("✅ PRELOAD \(prefix): Buffer ready for \(videoId) (buffered: \(currentBufferedSeconds)s, state: \(currentBufferState.description))")
                    // Update dot to be solid green by setting ready flag
                    nextVideoReady = true
                }

                // Calculate and log preloading completion time
                let preloadEndTime = CFAbsoluteTimeGetCurrent()
                let preloadDuration = preloadEndTime - preloadStart
                Logger.caching.info("⏱️ TIMING: \(isRandom ? "Random next" : "Next") video preloading completed in \(preloadDuration.formatted(.number.precision(.fractionLength(3)))) seconds")

                // No need to signal preloading complete - our phased approach handles this
                // Phase 2 (general caching) automatically starts after this method completes
                Logger.caching.info("✅ PHASE 1A COMPLETE: \(isRandom ? "Random next" : "Next") video successfully preloaded")

                break
            }

            // If not ready yet, wait briefly and check again
            Logger.caching.debug("⏳ PRELOAD \(prefix): Buffer not yet ready for \(videoId) (buffered: \(bufferedSeconds)s, state: \(bufferState.description))")
            try? await Task.sleep(for: .seconds(0.5))
        }
    }
}