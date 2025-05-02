//
//  VideoPlayerViewModel+VideoLoading.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import SwiftUI
import AVKit
import AVFoundation
import OSLog

// MARK: - Video Loading Extension
extension VideoPlayerViewModel {
    func loadIdentifiers() async {
        do {
            // Use user preferences when loading identifiers
            identifiers = try await videoLoadingService.loadIdentifiersWithUserPreferences()
            Logger.metadata.info("Successfully loaded \(self.identifiers.count) identifiers with user preferences")
        } catch {
            Logger.metadata.error("Failed to load identifiers: \(error.localizedDescription)")
            self.errorMessage = "Failed to load video identifiers: \(error.localizedDescription)"
            isInitializing = false
        }
    }
    
    // Public method to reload identifiers when collection preferences change
    func reloadIdentifiers() async {
        Logger.metadata.info("Reloading identifiers due to collection preference changes")
        
        // Clear the cache to ensure we don't show videos from collections that might now be disabled
        await cacheManager.clearCache()
        
        // Clear existing identifiers 
        identifiers = []
        
        // Load identifiers with new preferences
        await loadIdentifiers()
        
        // Start preloading new videos from the updated collection list
        Task {
            await ensureVideosAreCached()
        }
        
        // Note: We don't automatically load a new video or change the current one
        // The user will see the effect of their changes when they swipe to the next video
        Logger.metadata.info("Collection settings updated, changes will apply to next videos")
    }
    
    func loadRandomVideo(showImmediately: Bool = true) async {
        let overallStartTime = CFAbsoluteTimeGetCurrent()
        Logger.videoPlayback.info("Starting to load random video for swipe interface")
        
        // Only update UI loading state if we're showing immediately
        if showImmediately {
            isLoading = true
            errorMessage = nil
        }
        
        // Ensure we have identifiers loaded
        if identifiers.isEmpty {
            Logger.metadata.warning("Attempting to load video but identifiers array is empty, loading identifiers first")
            await loadIdentifiers()
            
            // Check again after loading
            if identifiers.isEmpty {
                Logger.metadata.error("No identifiers available after explicit load attempt")
                errorMessage = "No identifiers available. Make sure the identifiers.sqlite database is in the app bundle."
                isLoading = false
                isInitializing = false
                return
            }
        }
        
        // Clean up existing player
        playbackManager.cleanupPlayer()
        
        // Pre-emptively start caching next videos for smooth swipes
        Task {
            await ensureVideosAreCached()
        }
        
        do {
            // Load a random video using our service
            let videoInfo = try await videoLoadingService.loadRandomVideo()
            
            // Set the current video info
            currentIdentifier = videoInfo.identifier
            currentCollection = videoInfo.collection
            currentTitle = videoInfo.title
            currentDescription = videoInfo.description
            
            // Create a player with the seek position already applied
            let player = AVPlayer(playerItem: AVPlayerItem(asset: videoInfo.asset))
            let startTime = CMTime(seconds: videoInfo.startPosition, preferredTimescale: 600)
            
            // Log consistent video timing information when using from cache
            Logger.videoPlayback.info("VIDEO TIMING (PLAYING): Duration=\(self.playbackManager.videoDuration.formatted(.number.precision(.fractionLength(1))))s, Offset=\(videoInfo.startPosition.formatted(.number.precision(.fractionLength(1))))s (\(videoInfo.identifier))")
            
            // Seek to the correct position before we set it as the current player
            let seekStartTime = CFAbsoluteTimeGetCurrent()
            await player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
            let seekTime = CFAbsoluteTimeGetCurrent() - seekStartTime
            Logger.videoPlayback.info("Video seek completed in \(seekTime.formatted(.number.precision(.fractionLength(4)))) seconds")
            
            // Now set the player with the correct position already set
            // This will also extract and store the URL internally
            playbackManager.useExistingPlayer(player)
            
            // Always start playback of the video
            playbackManager.play()
            
            // Monitor buffer status
            if let playerItem = playbackManager.player?.currentItem {
                Task {
                    await playbackManager.monitorBufferStatus(for: playerItem)
                }
            }
            
            // Save the first loaded video to history
            if let currentVideo = await createCachedVideoFromCurrentState() {
                addVideoToHistory(currentVideo)
                updateCurrentCachedVideo(currentVideo)
                Logger.caching.info("Added initial video to history")
            }
            
            // Only update loading state if we're showing immediately
            if showImmediately {
                isLoading = false
            }
            
            // Start preloading the next video if needed
            await ensureVideosAreCached()
            
            let overallTime = CFAbsoluteTimeGetCurrent() - overallStartTime
            Logger.videoPlayback.info("Total video load time: \(overallTime.formatted(.number.precision(.fractionLength(4)))) seconds")
            
        } catch {
            Logger.videoPlayback.error("Failed to load video: \(error.localizedDescription)")
            
            if showImmediately {
                isLoading = false
                errorMessage = "Error loading video: \(error.localizedDescription)"
            }
            
            // Always exit initialization mode on error to prevent being stuck in loading
            isInitializing = false
        }
    }
}