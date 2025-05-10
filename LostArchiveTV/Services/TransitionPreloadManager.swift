//
//  TransitionPreloadManager.swift
//  LostArchiveTV
//
//  Created by Claude on 4/25/25.
//

import SwiftUI
import AVKit
import OSLog
import Foundation

class TransitionPreloadManager: ObservableObject {
    // Next (down) video properties
    @Published var nextVideoReady = false {
        didSet {
            // Log when the next video ready state changes
            if oldValue != self.nextVideoReady {
                Logger.caching.info("🚦 TRANSITION STATUS: Next video ready changed to \(self.nextVideoReady ? "true" : "false") on manager \(String(describing: ObjectIdentifier(self)))")

                // Debug - log the stack trace to see where this is being set
                let symbols = Thread.callStackSymbols.prefix(5).joined(separator: "\n")
                Logger.caching.info("🔍 CALL STACK: next state changed from \(oldValue) to \(self.nextVideoReady):\n\(symbols)")

                // Always post notification when nextVideoReady changes to ensure UI updates
                // This helps prevent mismatch between UI and actual swipe availability
                DispatchQueue.main.async {
                    Logger.caching.info("🚨 AUTO NOTIFICATION: Publishing CacheStatusChanged due to nextVideoReady change")
                    NotificationCenter.default.post(name: Notification.Name("CacheStatusChanged"), object: nil)
                }
            }
        }
    }
    @Published var nextPlayer: AVPlayer?
    @Published var nextTitle: String = ""
    @Published var nextCollection: String = ""
    @Published var nextDescription: String = ""
    @Published var nextIdentifier: String = ""
    @Published var nextFilename: String = ""
    @Published var nextTotalFiles: Int = 0

    // Previous (up) video properties
    @Published var prevVideoReady = false {
        didSet {
            // Log when the previous video ready state changes
            if oldValue != self.prevVideoReady {
                Logger.caching.info("🚦 TRANSITION STATUS: Previous video ready changed to \(self.prevVideoReady ? "true" : "false") on manager \(String(describing: ObjectIdentifier(self)))")

                // Always post notification when prevVideoReady changes to ensure UI updates
                // This helps prevent mismatch between UI and actual swipe availability
                DispatchQueue.main.async {
                    Logger.caching.info("🚨 AUTO NOTIFICATION: Publishing CacheStatusChanged due to prevVideoReady change")
                    NotificationCenter.default.post(name: Notification.Name("CacheStatusChanged"), object: nil)
                }
            }
        }
    }
    @Published var prevPlayer: AVPlayer?
    @Published var prevTitle: String = ""
    @Published var prevCollection: String = ""
    @Published var prevDescription: String = ""
    @Published var prevIdentifier: String = ""
    @Published var prevFilename: String = ""
    @Published var prevTotalFiles: Int = 0
    
    // Preload the next video while current one is playing
    func preloadNextVideo(provider: VideoProvider) async {
        Logger.caching.info("🔍 PRELOAD NEXT: Starting for \(String(describing: type(of: provider)))")

        // Log cache state for debugging
        if let cacheableProvider = provider as? CacheableProvider {
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
            }
            
            // Start asynchronous buffer monitoring task that will update UI status
            // as soon as the video is actually ready to play
            Task {
                Logger.caching.info("🔄 PRELOAD NEXT: Starting buffer monitoring for \(nextVideo.identifier)")
                let playerItem = player.currentItem
                
                // Start monitoring buffer status
                while !Task.isCancelled && playerItem == player.currentItem {
                    // Check if buffer is ready for smooth playback
                    if player.currentItem?.isPlaybackLikelyToKeepUp == true {
                        await MainActor.run {
                            Logger.caching.info("✅ PRELOAD NEXT: Buffer ready for \(nextVideo.identifier)")
                            // Update dot to be solid green by setting ready flag
                            nextVideoReady = true
                        }
                        break
                    }
                    
                    // If not ready yet, wait briefly and check again
                    Logger.caching.debug("⏳ PRELOAD NEXT: Buffer not yet ready for \(nextVideo.identifier)")
                    try? await Task.sleep(for: .seconds(0.5))
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
                let freshPlayerItem = AVPlayerItem(asset: videoInfo.asset)
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
                Task {
                    Logger.caching.info("🔄 PRELOAD RAND: Starting buffer monitoring for \(videoInfo.identifier)")
                    let playerItem = player.currentItem
                    
                    // Start monitoring buffer status
                    while !Task.isCancelled && playerItem == player.currentItem {
                        // Check if buffer is ready for smooth playback
                        if player.currentItem?.isPlaybackLikelyToKeepUp == true {
                            await MainActor.run {
                                Logger.caching.info("✅ PRELOAD RAND: Buffer ready for \(videoInfo.identifier)")
                                // Update dot to be solid green by setting ready flag
                                nextVideoReady = true
                            }
                            break
                        }
                        
                        // If not ready yet, wait briefly and check again
                        Logger.caching.debug("⏳ PRELOAD RAND: Buffer not yet ready for \(videoInfo.identifier)")
                        try? await Task.sleep(for: .seconds(0.5))
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
                    Task {
                        Logger.caching.info("🔄 PRELOAD FAV: Starting buffer monitoring for \(nextVideo.identifier)")
                        let playerItem = player.currentItem
                        
                        // Start monitoring buffer status
                        while !Task.isCancelled && playerItem == player.currentItem {
                            // Check if buffer is ready for smooth playback
                            if player.currentItem?.isPlaybackLikelyToKeepUp == true {
                                await MainActor.run {
                                    Logger.caching.info("✅ PRELOAD FAV: Buffer ready for \(nextVideo.identifier)")
                                    // Update dot to be solid green by setting ready flag
                                    nextVideoReady = true
                                }
                                break
                            }
                            
                            // If not ready yet, wait briefly and check again
                            Logger.caching.debug("⏳ PRELOAD FAV: Buffer not yet ready for \(nextVideo.identifier)")
                            try? await Task.sleep(for: .seconds(0.5))
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
    
    // Preload the previous video from history/sequence
    func preloadPreviousVideo(provider: VideoProvider) async {
        Logger.caching.info("🔍 PRELOAD PREV: Starting for \(String(describing: type(of: provider)))")
        
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
                    // Check if buffer is ready for smooth playback
                    if player.currentItem?.isPlaybackLikelyToKeepUp == true {
                        await MainActor.run {
                            Logger.caching.info("✅ PRELOAD PREV: Buffer ready for \(previousVideo.identifier)")
                            // Update dot to be solid green by setting ready flag
                            prevVideoReady = true
                        }
                        break
                    }
                    
                    // If not ready yet, wait briefly and check again
                    Logger.caching.debug("⏳ PRELOAD PREV: Buffer not yet ready for \(previousVideo.identifier)")
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
                        // For the main player, use PreloadService which has the most robust implementation
                        Logger.caching.info("🔄 CACHING: Using PreloadService for main player with \(identifiers.count) identifiers")
                        await cacheableProvider.preloadService.ensureVideosAreCached(
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