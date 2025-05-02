//
//  VideoTrimViewModel+Thumbnails.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import Foundation
import AVFoundation
import UIKit
import OSLog

// MARK: - Thumbnail Generation
extension VideoTrimViewModel {
    /// Generate thumbnails from the video asset
    func generateThumbnails(from asset: AVAsset) {
        // Calculate appropriate number of thumbnails based on video duration
        // We'll aim for roughly 1 thumbnail per 5 seconds of video
        let duration = assetDuration.seconds
        let idealCount = min(60, max(20, Int(ceil(duration / 5.0))))
        
        logger.debug("Generating \(idealCount) thumbnails for \(duration) second video")
        
        // Pre-allocate array with placeholders
        thumbnails = Array(repeating: nil, count: idealCount)
        
        // Use our trim manager to generate thumbnails
        trimManager.generateThumbnails(from: asset, count: idealCount) { [weak self] (images: [UIImage]) in
            guard let self = self else { return }
            
            // Switch to main thread for UI updates
            DispatchQueue.main.async {
                // Match returned images to our pre-allocated array
                for (index, image) in images.enumerated() {
                    if index < self.thumbnails.count {
                        self.thumbnails[index] = image
                    }
                }
                
                self.logger.debug("Generated \(images.count) thumbnails for trim interface")
            }
        }
    }
}