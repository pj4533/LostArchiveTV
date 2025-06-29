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
                prevCollection = previousVideo.collection
                prevDescription = previousVideo.description
                prevIdentifier = previousVideo.identifier
                prevFilename = previousVideo.mp4File.name
                prevTotalFiles = previousVideo.totalFiles
                
                // Store reference to previous player
                prevPlayer = player

                Logger.files.info("📊 PRELOAD PREV: Set prevTotalFiles to \(previousVideo.totalFiles) for \(previousVideo.identifier)")
                
                // CRITICAL: Connect buffer monitors to preloaded players
                if let provider = provider as? BaseVideoViewModel {
                    Logger.preloading.notice("🎯 PRELOAD: Calling updatePreloadMonitors to connect buffer monitor (previous)")
                    provider.updatePreloadedBufferingMonitors()
                }
            }
            
            // Start asynchronous buffer monitoring task that will update UI status
            // as soon as the video is actually ready to play
            let videoId = previousVideo.identifier
            let preloadStart = preloadStartTime
            
            // Start buffer monitoring in background
            Task {
                // Use the BufferingMonitor's state instead of calculating our own
                if let provider = provider as? BaseVideoViewModel {
                    await monitorPreviousVideoBufferViaMonitor(provider: provider, videoId: videoId, preloadStart: preloadStart)
                } else {
                    await monitorPreviousVideoBuffer(player: player, videoId: videoId, preloadStart: preloadStart)
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
    
    /// Monitor buffer status using the BufferingMonitor as single source of truth
    private func monitorPreviousVideoBufferViaMonitor(provider: BaseVideoViewModel, videoId: String, preloadStart: Double) async {
        Logger.caching.info("🔄 PRELOAD PREV: Starting buffer monitoring via BufferingMonitor for \(videoId)")
        
        // Give the monitor a moment to stabilize
        try? await Task.sleep(for: .milliseconds(300))
        
        // Wait for the monitor to be ready
        var consecutiveReadyChecks = 0
        while !Task.isCancelled {
            // Get the buffer state from the monitor (single source of truth)
            let bufferState = await MainActor.run {
                provider.previousBufferingMonitor?.bufferState ?? .unknown
            }
            let bufferSeconds = await MainActor.run {
                provider.previousBufferingMonitor?.bufferSeconds ?? 0
            }
            
            Logger.preloading.debug("🎯 MONITOR STATE: Prev video buffer from monitor: \(bufferSeconds)s, state=\(bufferState.description)")
            
            // Update buffer state
            await MainActor.run {
                self.updatePrevBufferState(bufferState)
            }
            
            // Check if buffer is ready - require 2 consecutive ready states to avoid false positives
            if bufferState.isReady {
                consecutiveReadyChecks += 1
                if consecutiveReadyChecks >= 2 {
                    await MainActor.run {
                        Logger.caching.info("✅ PRELOAD PREV: Buffer ready for \(videoId) (buffered: \(bufferSeconds)s, state: \(bufferState.description))")
                        self.prevVideoReady = true
                    }
                    
                    // Calculate and log preloading completion time
                    let preloadEndTime = CFAbsoluteTimeGetCurrent()
                    let preloadDuration = preloadEndTime - preloadStart
                    Logger.caching.info("⏱️ TIMING: Previous video preloading completed in \(preloadDuration.formatted(.number.precision(.fractionLength(3)))) seconds")
                    
                    break
                }
            } else {
                consecutiveReadyChecks = 0
            }
            
            // Wait briefly before checking again
            try? await Task.sleep(for: .seconds(0.5))
        }
    }
    
    /// Monitor buffer status for previous video asynchronously
    private func monitorPreviousVideoBuffer(player: AVPlayer, videoId: String, preloadStart: Double) async {
        Logger.caching.info("🔄 PRELOAD PREV: Starting buffer monitoring for \(videoId)")
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
            Logger.preloading.debug("🧮 BUFFER CALC: Prev video buffered=\(bufferedSeconds)s, state=\(bufferState.rawValue)")
            
            // Update buffer state
            await MainActor.run {
                self.updatePrevBufferState(bufferState)
            }
            
            // Check if buffer is ready - requires both conditions:
            // 1. isPlaybackLikelyToKeepUp is true
            // 2. Buffer state is ready (sufficient, good, or excellent)
            if playerItem?.isPlaybackLikelyToKeepUp == true && bufferState.isReady {
                // Capture values for logging
                let currentBufferedSeconds = bufferedSeconds
                let currentBufferState = bufferState
                
                await MainActor.run {
                    Logger.caching.info("✅ PRELOAD PREV: Buffer ready for \(videoId) (buffered: \(currentBufferedSeconds)s, state: \(currentBufferState.description))")
                    // Update dot to be solid green by setting ready flag
                    prevVideoReady = true
                }

                // Calculate and log preloading completion time
                let preloadEndTime = CFAbsoluteTimeGetCurrent()
                let preloadDuration = preloadEndTime - preloadStart
                Logger.caching.info("⏱️ TIMING: Previous video preloading completed in \(preloadDuration.formatted(.number.precision(.fractionLength(3)))) seconds")

                // No need to signal preloading complete - our phased approach handles this
                // Phase 2 (general caching) automatically starts after this method completes
                Logger.caching.info("✅ PHASE 1B COMPLETE: Previous video successfully preloaded")

                break
            }

            // If not ready yet, wait briefly and check again
            Logger.caching.debug("⏳ PRELOAD PREV: Buffer not yet ready for \(videoId) (buffered: \(bufferedSeconds)s, state: \(bufferState.description))")
            try? await Task.sleep(for: .seconds(0.5))
        }
    }
}