//
//  SearchViewModel+Favorites.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import Foundation
import AVKit
import AVFoundation
import OSLog
import SwiftUI

// MARK: - Favorites Support
extension SearchViewModel {
    /// Create a saved video from search result
    func createSavedVideo() async -> CachedVideo? {
        guard let identifier = currentIdentifier, let collection = currentCollection else { return nil }
        
        let archiveIdentifier = ArchiveIdentifier(identifier: identifier, collection: collection)
        
        do {
            return try await createCachedVideo(for: archiveIdentifier)
        } catch {
            Logger.caching.error("Failed to create saved video: \(error.localizedDescription)")
            return nil
        }
    }
}