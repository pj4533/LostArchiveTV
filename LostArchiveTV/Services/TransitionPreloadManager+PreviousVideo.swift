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
        // Store weak reference to provider for buffer state queries
        if let baseProvider = provider as? BaseVideoViewModel {
            self.provider = baseProvider
        }
        
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
            
            // Add the preloaded video to the cache to prevent duplicate loading
            if let cacheableProvider = provider as? CacheableProvider {
                await cacheableProvider.cacheManager.addCachedVideo(previousVideo)
                Logger.caching.info("📦 PRELOAD PREV: Added preloaded video to cache: \(previousVideo.identifier)")
            }
            
            // Delay briefly to ensure monitors are connected before sending signal
            Task {
                try? await Task.sleep(for: .milliseconds(100))
                
                // NOW send the preloading started notification since we're actually preloading a new video
                if let cacheableProvider = provider as? CacheableProvider {
                    Logger.preloading.notice("📢 SIGNAL: Sending preloading started for PREVIOUS video preload (delayed for monitor connection)")
                    await cacheableProvider.cacheService.notifyCachingStarted()
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
            let (bufferState, bufferSeconds) = await MainActor.run {
                let state = provider.previousBufferingMonitor?.bufferState ?? .unknown
                let seconds = provider.previousBufferingMonitor?.bufferSeconds ?? 0
                return (state, seconds)
            }
            
            Logger.preloading.debug("🎯 MONITOR STATE: Prev video buffer from monitor: \(bufferSeconds)s, state=\(bufferState.description)")
            
            // Publish buffer state update
            await MainActor.run {
                self.publishBufferStateUpdate()
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
    
}