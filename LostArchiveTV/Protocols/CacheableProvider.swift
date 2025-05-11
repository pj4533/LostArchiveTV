//
//  CacheableProvider.swift
//  LostArchiveTV
//
//  Created by Claude on 5/3/25.
//

import Foundation

/// Protocol that extends VideoProvider to add caching capabilities
protocol CacheableProvider: VideoProvider {
    /// The cache service used for video caching
    var cacheService: VideoCacheService { get }
    
    /// The cache manager for storing cached videos
    var cacheManager: VideoCacheManager { get }
    
    /// The archive service for fetching video metadata and files
    var archiveService: ArchiveService { get }
    
    /// Returns a list of identifiers that can be used for general video caching
    /// This allows different providers to specify which videos should be considered for the cache
    func getIdentifiersForGeneralCaching() -> [ArchiveIdentifier]
}