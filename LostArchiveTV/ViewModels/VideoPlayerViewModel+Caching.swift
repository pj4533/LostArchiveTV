//
//  VideoPlayerViewModel+Caching.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import SwiftUI
import AVKit
import AVFoundation
import OSLog

// MARK: - Caching and Favorites Extension
extension VideoPlayerViewModel {
    func ensureVideosAreCached() async {
        await preloadService.ensureVideosAreCached(
            cacheManager: cacheManager,
            archiveService: archiveService,
            identifiers: identifiers
        )
    }
    
    // MARK: - Favorites Functionality
    
    var currentCachedVideo: CachedVideo? {
        _currentCachedVideo
    }
    
    // Method to update the current cached video reference
    func updateCurrentCachedVideo(_ video: CachedVideo?) {
        _currentCachedVideo = video
        objectWillChange.send()
    }
}