//
//  VideoHistoryManager.swift
//  LostArchiveTV
//
//  Created by Claude on 4/25/25.
//

import Foundation
import OSLog

class VideoHistoryManager {
    // Video history tracking - simple array with current index
    private var videoHistory: [CachedVideo] = []
    private var currentHistoryIndex: Int = -1
    
    // Add a video to history (at the end)
    func addVideo(_ video: CachedVideo) {
        // If we're not at the end of history, truncate forward history
        if currentHistoryIndex < self.videoHistory.count - 1 {
            self.videoHistory = Array(self.videoHistory[0...self.currentHistoryIndex])
        }
        
        // Check if we're about to add a duplicate of the last video
        if let lastVideo = self.videoHistory.last, lastVideo.identifier == video.identifier {
            Logger.caching.info("Skipping duplicate video in history: \(video.identifier)")
            return
        }
        
        // Add new video to history
        self.videoHistory.append(video)
        self.currentHistoryIndex = self.videoHistory.count - 1
        
        Logger.caching.info("Added video to history: \(video.identifier), history size: \(self.videoHistory.count), index: \(self.currentHistoryIndex)")
    }
    
    // Get previous video from history (moves the index)
    func getPreviousVideo() -> CachedVideo? {
        guard currentHistoryIndex > 0, !videoHistory.isEmpty else {
            Logger.caching.info("No previous video in history")
            return nil
        }
        
        self.currentHistoryIndex -= 1
        let video = self.videoHistory[self.currentHistoryIndex]
        Logger.caching.info("💫 HISTORY: Moving back in history to index \(self.currentHistoryIndex): \(video.identifier)")
        return video
    }
    
    // Get next video from history (or nil if we need a new one) (moves the index)
    func getNextVideo() -> CachedVideo? {
        // If we're at the end of history, return nil (caller should load a new video)
        guard currentHistoryIndex < videoHistory.count - 1, !videoHistory.isEmpty else {
            Logger.caching.info("💫 HISTORY: At end of history, need to load a new video")
            return nil
        }
        
        // Move forward in history
        self.currentHistoryIndex += 1
        let video = self.videoHistory[self.currentHistoryIndex]
        Logger.caching.info("💫 HISTORY: Moving forward in history to index \(self.currentHistoryIndex): \(video.identifier)")
        return video
    }
    
    // Peek at the previous video without changing the current index
    func peekPreviousVideo() -> CachedVideo? {
        guard currentHistoryIndex > 0, !videoHistory.isEmpty else {
            Logger.caching.info("👁️ HISTORY PEEK: No previous video in history")
            return nil
        }
        
        let peekIndex = currentHistoryIndex - 1
        let video = self.videoHistory[peekIndex]
        Logger.caching.info("👁️ HISTORY PEEK: Peeking at previous index \(peekIndex): \(video.identifier)")
        return video
    }
    
    // Peek at the next video without changing the current index
    func peekNextVideo() -> CachedVideo? {
        // If we're at the end of history, return nil (caller should load a new video)
        guard currentHistoryIndex < videoHistory.count - 1, !videoHistory.isEmpty else {
            Logger.caching.info("👁️ HISTORY PEEK: At end of history (peek), need to load a new video")
            return nil
        }
        
        let peekIndex = currentHistoryIndex + 1
        let video = self.videoHistory[peekIndex]
        Logger.caching.info("👁️ HISTORY PEEK: Peeking at next index \(peekIndex): \(video.identifier)")
        return video
    }
    
    // Check if we're at the end of history
    func isAtEnd() -> Bool {
        return currentHistoryIndex >= videoHistory.count - 1
    }
}