//
//  FavoritesManager.swift
//  LostArchiveTV
//
//  Created by Claude on 4/24/25.
//

import Foundation
import SwiftUI
import OSLog
import AVKit

class FavoritesManager: ObservableObject {
    @Published private(set) var favorites: [CachedVideo] = []
    private let favoritesKey = "com.lostarchivetv.favorites"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    struct StoredFavorite: Codable {
        let identifier: String
        let collection: String
        let title: String
        let description: String
        let videoURLString: String
        let startPosition: Double
    }
    
    init() {
        loadFavorites()
    }
    
    func loadFavorites() {
        favorites = []
        Logger.metadata.debug("Loading favorites from UserDefaults")
        guard let data = UserDefaults.standard.data(forKey: favoritesKey),
              let storedFavorites = try? decoder.decode([StoredFavorite].self, from: data) else {
            Logger.metadata.debug("No favorites found in UserDefaults")
            return
        }
        
        // Convert stored favorites to CachedVideo objects
        for storedFavorite in storedFavorites {
            if let videoURL = URL(string: storedFavorite.videoURLString) {
                // Create an asset from the URL
                let asset = AVURLAsset(url: videoURL)
                let playerItem = AVPlayerItem(asset: asset)
                
                // Create metadata objects
                let metadata = ArchiveMetadata(
                    files: [],
                    metadata: ItemMetadata(
                        identifier: storedFavorite.identifier,
                        title: storedFavorite.title,
                        description: storedFavorite.description
                    )
                )
                
                // Create basic MP4 file representation
                let mp4File = ArchiveFile(
                    name: storedFavorite.identifier,
                    format: "h.264",
                    size: "",
                    length: nil
                )
                
                // Create cached video
                let cachedVideo = CachedVideo(
                    identifier: storedFavorite.identifier,
                    collection: storedFavorite.collection,
                    metadata: metadata,
                    mp4File: mp4File,
                    videoURL: videoURL,
                    asset: asset,
                    playerItem: playerItem,
                    startPosition: storedFavorite.startPosition
                )
                
                favorites.append(cachedVideo)
            }
        }
        
        Logger.metadata.debug("Loaded \(self.favorites.count) favorite videos from UserDefaults")
    }
    
    func saveFavorites() {
        let storedFavorites = favorites.map { video -> StoredFavorite in
            StoredFavorite(
                identifier: video.identifier,
                collection: video.collection,
                title: video.title,
                description: video.description,
                videoURLString: video.videoURL.absoluteString,
                startPosition: video.startPosition
            )
        }
        
        if let data = try? encoder.encode(storedFavorites) {
            UserDefaults.standard.set(data, forKey: favoritesKey)
            UserDefaults.standard.synchronize()
            Logger.metadata.debug("Saved \(storedFavorites.count) favorites to UserDefaults")
        }
    }
    
    func addFavorite(_ video: CachedVideo) {
        if !isFavorite(video) {
            favorites.append(video)
            saveFavorites()
            Logger.metadata.debug("Added video to favorites: \(video.identifier)")
        }
    }
    
    func removeFavorite(_ video: CachedVideo) {
        favorites.removeAll { $0.identifier == video.identifier }
        saveFavorites()
        Logger.metadata.debug("Removed video from favorites: \(video.identifier)")
    }
    
    func isFavorite(_ video: CachedVideo) -> Bool {
        return favorites.contains { $0.identifier == video.identifier }
    }
    
    func isFavoriteIdentifier(_ identifier: String) -> Bool {
        return favorites.contains { $0.identifier == identifier }
    }
    
    func toggleFavorite(_ video: CachedVideo) {
        if isFavorite(video) {
            removeFavorite(video)
        } else {
            addFavorite(video)
        }
    }
}