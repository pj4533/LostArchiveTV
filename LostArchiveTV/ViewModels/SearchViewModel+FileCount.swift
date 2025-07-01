//
//  SearchViewModel+FileCount.swift
//  LostArchiveTV
//
//  Created by Claude on 2025-06-30.
//

import Foundation
import OSLog

extension SearchViewModel {
    // MARK: - File Count Cache Methods
    
    /// Get cached file count for an identifier
    /// - Parameter identifier: The archive identifier
    /// - Returns: The cached file count if available, nil otherwise
    nonisolated func getCachedFileCount(for identifier: String) -> Int? {
        return _fileCountCache[identifier]
    }
    
    /// Fetch file count for an identifier and cache the result
    /// - Parameter identifier: The archive identifier
    /// - Returns: The file count, or nil if there was an error
    func fetchFileCount(for identifier: String) async -> Int? {
        Logger.caching.debug("🔍 DEBUG: fetchFileCount called for: \(identifier)")
        
        // Check cache first
        if let cachedCount = _fileCountCache[identifier] {
            Logger.caching.info("🔍 DEBUG: File count cache hit for \(identifier): \(cachedCount)")
            return cachedCount
        }
        
        do {
            // Fetch metadata to calculate file count
            Logger.caching.info("🔍 DEBUG: Fetching metadata for file count calculation: \(identifier)")
            let metadata = try await archiveService.fetchMetadata(for: identifier)
            Logger.caching.debug("🔍 DEBUG: Got metadata with \(metadata.files.count) files")
            
            // Use the static method from VideoLoadingService to calculate file count
            let fileCount = VideoLoadingService.calculateFileCount(from: metadata)
            Logger.caching.debug("🔍 DEBUG: calculateFileCount returned: \(fileCount)")
            
            // Cache the result and trigger UI updates
            _fileCountCache[identifier] = fileCount
            fileCountCacheVersion += 1  // Trigger UI update through @Published
            Logger.caching.info("🔍 DEBUG: Cached file count for \(identifier): \(fileCount)")
            
            return fileCount
        } catch {
            Logger.caching.error("🔍 DEBUG: Failed to fetch file count for \(identifier): \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Proactively fetch file counts for search results to improve UI responsiveness
    /// - Parameter results: The search results to fetch file counts for
    func prefetchFileCounts(for results: [SearchResult]) async {
        Logger.caching.info("🔍 DEBUG: Starting prefetch of file counts for \(results.count) results")
        
        // Fetch file counts for the first 10 results (or all if less than 10)
        let prefetchCount = min(10, results.count)
        
        for i in 0..<prefetchCount {
            let identifier = results[i].identifier.identifier
            
            // Skip if already cached
            if _fileCountCache[identifier] != nil {
                continue
            }
            
            // Fetch file count
            let _ = await fetchFileCount(for: identifier)
            
            // Small delay to avoid overwhelming the server
            try? await Task.sleep(for: .milliseconds(100))
        }
        
        Logger.caching.info("🔍 DEBUG: Completed prefetch of file counts for first \(prefetchCount) results")
    }
}