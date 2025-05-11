//
//  TransitionPreloadManager+PreviousVideo.swift
//  LostArchiveTV
//
//  Created by Claude on 5/11/25.
//

import SwiftUI
import AVKit
import OSLog
import Foundation

extension TransitionPreloadManager {
    // Preload the previous video from history/sequence
    func preloadPreviousVideo(provider: VideoProvider) async {
        // Log timestamp when preloading starts for performance tracking
        let preloadStartTime = CFAbsoluteTimeGetCurrent()

        Logger.caching.info("🔍 PHASE 1B: Preloading PREVIOUS video for \(String(describing: type(of: provider))) at time \(preloadStartTime)")

        // Signal to the VideoCacheService that preloading has started
        // This will halt ALL caching operations until preloading is complete
        if let cacheableProvider = provider as? CacheableProvider {
            // Explicitly signal preloading has started - this will block ALL caching
            await cacheableProvider.cacheService.setPreloadingStarted()
        }
        
        // Reset previous video ready flag
        await MainActor.run {
            prevVideoReady = false
        }
        
        // IMPORTANT: Use peekPreviousVideo instead of getPreviousVideo to avoid modifying the history index
        if let previousVideo = await provider.peekPreviousVideo() {
            Logger.caching.info("🔍 PRELOAD PREV: Found previous video in history: \(previousVideo.identifier)")
            
            // Create a new player for the asset
            let freshPlayerItem = AVPlayerItem(asset: previousVideo.asset)
            let player = AVPlayer(playerItem: freshPlayerItem)
            
            // Prepare player but keep it paused and muted
            player.isMuted = true
            player.pause()
            
            // Seek to the start position
            let startTime = CMTime(seconds: previousVideo.startPosition, preferredTimescale: 600)
            await player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)

            // Update UI on main thread immediately with metadata
            await MainActor.run {
                // Update previous video metadata
                prevTitle = previousVideo.title
                prevCollection = previousVideo.collection ?? ""
                prevDescription = previousVideo.description
                prevIdentifier = previousVideo.identifier
                prevFilename = previousVideo.mp4File.name
                prevTotalFiles = previousVideo.totalFiles
                
                // Store reference to previous player
                prevPlayer = player

                Logger.files.info("📊 PRELOAD PREV: Set prevTotalFiles to \(previousVideo.totalFiles) for \(previousVideo.identifier)")
            }
            
            // Start asynchronous buffer monitoring task that will update UI status
            // as soon as the video is actually ready to play
            Task {
                Logger.caching.info("🔄 PRELOAD PREV: Starting buffer monitoring for \(previousVideo.identifier)")
                let playerItem = player.currentItem
                
                // Start monitoring buffer status
                while !Task.isCancelled && playerItem == player.currentItem {
                    // Get buffer ranges to check actual loaded time
                    let loadedTimeRanges = playerItem?.loadedTimeRanges ?? []

                    // Calculate buffered duration (only count the first range which is what we're playing)
                    var bufferedSeconds = 0.0
                    if !loadedTimeRanges.isEmpty {
                        let firstRange = loadedTimeRanges[0].timeRangeValue
                        bufferedSeconds = firstRange.duration.seconds
                    }

                    // Check if buffer is ready - requires both conditions:
                    // 1. isPlaybackLikelyToKeepUp is true
                    // 2. At least 1 second of video is actually buffered
                    if playerItem?.isPlaybackLikelyToKeepUp == true && bufferedSeconds >= 1.0 {
                        await MainActor.run {
                            Logger.caching.info("✅ PRELOAD PREV: Buffer ready for \(previousVideo.identifier) (buffered: \(bufferedSeconds)s)")
                            // Update dot to be solid green by setting ready flag
                            prevVideoReady = true
                        }

                        // Calculate and log preloading completion time
                        let preloadEndTime = CFAbsoluteTimeGetCurrent()
                        let preloadDuration = preloadEndTime - preloadStartTime
                        Logger.caching.info("⏱️ TIMING: Previous video preloading completed in \(preloadDuration.formatted(.number.precision(.fractionLength(3)))) seconds")

                        // No need to signal preloading complete - our phased approach handles this
                        // Phase 2 (general caching) automatically starts after this method completes
                        Logger.caching.info("✅ PHASE 1B COMPLETE: Previous video successfully preloaded")

                        break
                    }

                    // If not ready yet, wait briefly and check again
                    Logger.caching.debug("⏳ PRELOAD PREV: Buffer not yet ready for \(previousVideo.identifier) (buffered: \(bufferedSeconds)s)")
                    try? await Task.sleep(for: .seconds(0.5))
                }
            }
            
            Logger.caching.info("✅ PRELOAD PREV: Successfully prepared previous video: \(previousVideo.identifier)")
            return
        } 
        
        // Special handling for FavoritesViewModel
        if let favoritesViewModel = provider as? FavoritesViewModel {
            // For favorites view, check if we still have favorites in the list
            let favorites = await MainActor.run { favoritesViewModel.favorites }
            
            // If we have more than one favorite, circularly navigate to enable looping
            if favorites.count > 1 {
                // We should have been able to get a previous video above, so if we reached here, something's wrong
                Logger.caching.warning("Failed to preload previous favorite video")
            } else {
                // If only one favorite exists, don't enable swiping
                Logger.caching.info("Only one favorite video found, not marking previous as ready")
            }
        } else {
            Logger.caching.warning("No previous video available in sequence")
        }
    }
}