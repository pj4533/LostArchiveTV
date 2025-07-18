//
//  FavoritesManagerTests.swift
//  LostArchiveTVTests
//
//  Created by Claude on 5/2/25.
//

import Testing
import AVKit
@testable import LATV

struct FavoritesManagerTests {
    
    // Helper function to create a test video
    func createTestVideo(identifier: String, collection: String = "test") -> CachedVideo {
        let url = URL(string: "https://example.com/test/\(identifier).mp4")!
        let asset = AVURLAsset(url: url)
        
        let metadata = ArchiveMetadata(
            files: [],
            metadata: ItemMetadata(
                identifier: identifier,
                title: "Test Title \(identifier)",
                description: "Test Description \(identifier)"
            )
        )
        
        let mp4File = ArchiveFile(
            name: "\(identifier).mp4",
            format: "MPEG4",
            size: "1000",
            length: "120"
        )
        
        return CachedVideo(
            identifier: identifier,
            collection: collection,
            metadata: metadata,
            mp4File: mp4File,
            videoURL: url,
            asset: asset,
            startPosition: 0.0,
            addedToFavoritesAt: nil,
            totalFiles: 1
        )
    }
    
    @Test
    func addFavorite_storesVideoWithTimestamp() {
        // Arrange
        // Clear any existing favorites BEFORE creating the manager
        UserDefaults.standard.removeObject(forKey: "com.lostarchivetv.favorites")
        UserDefaults.standard.synchronize()
        
        let favoritesManager = FavoritesManager()
        let initialCount = favoritesManager.totalFavorites
        
        let video = createTestVideo(identifier: "test123")
        
        // Act
        favoritesManager.addFavorite(video)
        
        // Assert
        #expect(favoritesManager.totalFavorites == initialCount + 1)
        #expect(favoritesManager.isFavorite(video))
        #expect(favoritesManager.isFavoriteIdentifier("test123"))
        
        let retrievedFavorites = favoritesManager.getFavorites()
        #expect(retrievedFavorites.count >= 1)
        // Find our added video in the list (might not be at index 0 due to persisted data)
        let addedVideo = retrievedFavorites.first { $0.identifier == "test123" }
        #expect(addedVideo != nil)
        #expect(addedVideo?.addedToFavoritesAt != nil)
    }
    
    @Test
    func removeFavorite_removesVideoFromFavorites() {
        // Arrange
        // Clear any existing favorites BEFORE creating the manager
        UserDefaults.standard.removeObject(forKey: "com.lostarchivetv.favorites")
        UserDefaults.standard.synchronize()
        
        let favoritesManager = FavoritesManager()
        
        let video = createTestVideo(identifier: "test123")
        favoritesManager.addFavorite(video)
        
        // Initial state verification
        #expect(favoritesManager.totalFavorites == 1)
        
        // Act
        favoritesManager.removeFavorite(video)
        
        // Assert
        #expect(favoritesManager.totalFavorites == 0)
        #expect(!favoritesManager.isFavorite(video))
        #expect(!favoritesManager.isFavoriteIdentifier("test123"))
        
        let retrievedFavorites = favoritesManager.getFavorites()
        #expect(retrievedFavorites.isEmpty)
    }
    
    @Test
    func toggleFavorite_addsWhenNotPresent() {
        // Arrange
        // Clear any existing favorites BEFORE creating the manager
        UserDefaults.standard.removeObject(forKey: "com.lostarchivetv.favorites")
        UserDefaults.standard.synchronize()
        
        let favoritesManager = FavoritesManager()
        
        let video = createTestVideo(identifier: "test123")
        
        // Initial state verification
        #expect(!favoritesManager.isFavorite(video))
        
        // Act
        favoritesManager.toggleFavorite(video)
        
        // Assert
        #expect(favoritesManager.isFavorite(video))
    }
    
    @Test
    func toggleFavorite_removesWhenPresent() {
        // Arrange
        // Clear any existing favorites BEFORE creating the manager
        UserDefaults.standard.removeObject(forKey: "com.lostarchivetv.favorites")
        UserDefaults.standard.synchronize()
        
        let favoritesManager = FavoritesManager()
        
        let video = createTestVideo(identifier: "test123")
        favoritesManager.addFavorite(video)
        
        // Initial state verification
        #expect(favoritesManager.isFavorite(video))
        
        // Act
        favoritesManager.toggleFavorite(video)
        
        // Assert
        #expect(!favoritesManager.isFavorite(video))
    }
    
    @Test
    func getFavorites_withPagination_returnsCorrectResults() {
        // Arrange
        // Clear any existing favorites BEFORE creating the manager
        UserDefaults.standard.removeObject(forKey: "com.lostarchivetv.favorites")
        UserDefaults.standard.synchronize()
        
        let favoritesManager = FavoritesManager()
        
        // Add 25 videos
        for i in 1...25 {
            let video = createTestVideo(identifier: "test\(i)")
            favoritesManager.addFavorite(video)
        }
        
        // Initial state verification
        #expect(favoritesManager.totalFavorites == 25)
        
        // Act
        let firstPage = favoritesManager.getFavorites(page: 0, pageSize: 10)
        let secondPage = favoritesManager.getFavorites(page: 1, pageSize: 10)
        let thirdPage = favoritesManager.getFavorites(page: 2, pageSize: 10)
        
        // Assert
        #expect(firstPage.count == 10)
        #expect(secondPage.count == 10)
        #expect(thirdPage.count == 5)
        
        // Check that favorites are added at the beginning (newest first)
        // So test25 should be first, then test24, etc.
        #expect(firstPage[0].identifier == "test25")
        #expect(firstPage[9].identifier == "test16")
        #expect(secondPage[0].identifier == "test15")
        #expect(thirdPage[4].identifier == "test1")
    }
    
    @Test
    func hasMoreFavorites_returnsCorrectResult() {
        // Arrange
        // Clear any existing favorites BEFORE creating the manager
        UserDefaults.standard.removeObject(forKey: "com.lostarchivetv.favorites")
        UserDefaults.standard.synchronize()
        
        let favoritesManager = FavoritesManager()
        
        // Add 15 videos
        for i in 1...15 {
            let video = createTestVideo(identifier: "test\(i)")
            favoritesManager.addFavorite(video)
        }
        
        // Act & Assert
        #expect(favoritesManager.hasMoreFavorites(currentCount: 0))
        #expect(favoritesManager.hasMoreFavorites(currentCount: 10))
        // Videos are added in reverse order, so when we reach the totalFavorites, 
        // hasMoreFavorites should return false
        #expect(!favoritesManager.hasMoreFavorites(currentCount: favoritesManager.totalFavorites))
    }
}
