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

// MARK: - Favorites Extension
extension VideoPlayerViewModel {
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