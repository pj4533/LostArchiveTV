//
//  VideoCacheManagerTests.swift
//  LostArchiveTVTests
//
//  Created by Claude on 4/19/25.
//

import Testing
import AVKit
@testable import LostArchiveTV

struct VideoCacheManagerTests {
    
    // Helper function to create a test CachedVideo
    private func createTestVideo(identifier: String = "test") -> CachedVideo {
        let metadata = ArchiveMetadata(
            files: [ArchiveFile(name: "test.mp4", format: "MPEG4", size: "1000000", length: "120")],
            metadata: ItemMetadata(identifier: identifier, title: "Test Video", description: "Test Description")
        )
        
        let file = ArchiveFile(name: "test.mp4", format: "MPEG4", size: "1000000", length: "120")
        let url = URL(string: "https://example.com/\(identifier)/test.mp4")!
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        
        return CachedVideo(
            identifier: identifier,
            metadata: metadata,
            mp4File: file,
            videoURL: url,
            asset: asset,
            playerItem: playerItem,
            startPosition: 10.0
        )
    }
    
    @Test
    func addCachedVideo_increasesCount() async {
        // Arrange
        let cacheManager = VideoCacheManager()
        let video = createTestVideo()
        
        // Act
        await cacheManager.addCachedVideo(video)
        
        // Assert
        let count = await cacheManager.cacheCount()
        #expect(count == 1)
        
        let cachedVideos = await cacheManager.getCachedVideos()
        #expect(cachedVideos.count == 1)
        #expect(cachedVideos[0].identifier == "test")
    }
    
    @Test
    func removeFirstCachedVideo_decreasesCount() async {
        // Arrange
        let cacheManager = VideoCacheManager()
        let video1 = createTestVideo(identifier: "test1")
        let video2 = createTestVideo(identifier: "test2")
        
        await cacheManager.addCachedVideo(video1)
        await cacheManager.addCachedVideo(video2)
        
        // Act
        let removedVideo = await cacheManager.removeFirstCachedVideo()
        
        // Assert
        let count = await cacheManager.cacheCount()
        #expect(count == 1)
        #expect(removedVideo != nil)
        #expect(removedVideo?.identifier == "test1")
        
        let remainingVideos = await cacheManager.getCachedVideos()
        #expect(remainingVideos.count == 1)
        #expect(remainingVideos[0].identifier == "test2")
    }
    
    @Test
    func removeFirstCachedVideo_fromEmptyCache_returnsNil() async {
        // Arrange
        let cacheManager = VideoCacheManager()
        
        // Act
        let removedVideo = await cacheManager.removeFirstCachedVideo()
        
        // Assert
        #expect(removedVideo == nil)
    }
    
    @Test
    func clearCache_removesAllVideos() async {
        // Arrange
        let cacheManager = VideoCacheManager()
        let video1 = createTestVideo(identifier: "test1")
        let video2 = createTestVideo(identifier: "test2")
        
        await cacheManager.addCachedVideo(video1)
        await cacheManager.addCachedVideo(video2)
        
        // Verify initial state
        var count = await cacheManager.cacheCount()
        #expect(count == 2)
        
        // Act
        await cacheManager.clearCache()
        
        // Assert
        count = await cacheManager.cacheCount()
        #expect(count == 0)
        
        let isEmpty = await cacheManager.isCacheEmpty()
        #expect(isEmpty)
    }
    
    @Test
    func getMaxCacheSize_returnsExpectedValue() async {
        // Arrange
        let cacheManager = VideoCacheManager()
        
        // Act
        let maxSize = await cacheManager.getMaxCacheSize()
        
        // Assert
        #expect(maxSize == 3) // Default value from implementation
    }
    
    @Test
    func cacheCount_returnsCorrectCount() async {
        // Arrange
        let cacheManager = VideoCacheManager()
        let video1 = createTestVideo(identifier: "test1")
        let video2 = createTestVideo(identifier: "test2")
        
        // Initially empty
        var count = await cacheManager.cacheCount()
        #expect(count == 0)
        
        // Add first video
        await cacheManager.addCachedVideo(video1)
        count = await cacheManager.cacheCount()
        #expect(count == 1)
        
        // Add second video
        await cacheManager.addCachedVideo(video2)
        count = await cacheManager.cacheCount()
        #expect(count == 2)
        
        // Remove one video
        _ = await cacheManager.removeFirstCachedVideo()
        count = await cacheManager.cacheCount()
        #expect(count == 1)
    }
    
    @Test
    func isCacheEmpty_returnsCorrectValue() async {
        // Arrange
        let cacheManager = VideoCacheManager()
        let video = createTestVideo()
        
        // Initially empty
        var isEmpty = await cacheManager.isCacheEmpty()
        #expect(isEmpty)
        
        // Add a video
        await cacheManager.addCachedVideo(video)
        isEmpty = await cacheManager.isCacheEmpty()
        #expect(!isEmpty)
        
        // Remove the video
        _ = await cacheManager.removeFirstCachedVideo()
        isEmpty = await cacheManager.isCacheEmpty()
        #expect(isEmpty)
    }
}