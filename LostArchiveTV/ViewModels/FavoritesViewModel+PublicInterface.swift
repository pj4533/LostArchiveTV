//
//  FavoritesViewModel+PublicInterface.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import SwiftUI
import AVKit
import AVFoundation
import OSLog

// MARK: - Public Interface
extension FavoritesViewModel {
    var favorites: [CachedVideo] {
        favoritesManager.favorites
    }
    
    func isFavorite(_ video: CachedVideo) -> Bool {
        favoritesManager.isFavorite(video)
    }
}