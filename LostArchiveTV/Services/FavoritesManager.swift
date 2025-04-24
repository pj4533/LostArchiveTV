//
//  FavoritesManager.swift
//  LostArchiveTV
//
//  Created by Claude on 4/24/25.
//

import Foundation
import SwiftUI
import OSLog

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
        
        // We'll load the actual CachedVideo objects when we need to display them
        // For now, we just populate the identifiers list
        Logger.metadata.debug("Loaded \(storedFavorites.count) favorite identifiers")
    }
    
    func saveFavorites() {
        let storedFavorites = favorites.map { video -> StoredFavorite in
            StoredFavorite(
                identifier: video.identifier,
                collection: video.collection,
                title: video.title,
                description: video.description,
                videoURLString: video.videoURL.absoluteString
            )
        }
        
        if let data = try? encoder.encode(storedFavorites) {
            UserDefaults.standard.set(data, forKey: favoritesKey)
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
    
    func toggleFavorite(_ video: CachedVideo) {
        if isFavorite(video) {
            removeFavorite(video)
        } else {
            addFavorite(video)
        }
    }
}