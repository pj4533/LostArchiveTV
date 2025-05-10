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
    /// Generate thumbnails from the video asset with improved reliability
    func generateThumbnails(from asset: AVAsset) {
        // Calculate appropriate number of thumbnails based on video duration
        // We'll aim for roughly 1 thumbnail per 5 seconds, but limit to reasonable numbers
        let duration = assetDuration.seconds
        let idealCount = min(30, max(10, Int(ceil(duration / 5.0))))

        logger.debug("trim: generating \(idealCount) thumbnails for \(duration) second video")

        // Clear any existing thumbnails and pre-allocate array with placeholders
        self.thumbnails = Array(repeating: nil, count: idealCount)

        // Use Task to handle thumbnail generation asynchronously but with better control
        Task { @MainActor in
            do {
                // Use our trim manager to generate thumbnails
                logger.debug("trim: calling thumbnail generator")

                // Generate thumbnails with a dedicated Task
                let images = try await trimManager.generateThumbnailsAsync(from: asset, count: idealCount)

                logger.debug("trim: received \(images.count) thumbnails")

                if images.isEmpty {
                    logger.error("trim: no thumbnails were generated")
                    return
                }

                // Verify we're still active before updating UI
                guard self.directPlayer != nil else {
                    logger.debug("trim: thumbnail generation completed but view model is no longer active")
                    return
                }

                // Match returned images to our pre-allocated array
                var updatedThumbnails = Array(repeating: nil as UIImage?, count: idealCount)
                for (index, image) in images.enumerated() {
                    if index < updatedThumbnails.count {
                        updatedThumbnails[index] = image
                    }
                }

                // Update at once for better UI performance
                self.thumbnails = updatedThumbnails
                logger.debug("trim: updated thumbnails UI with \(updatedThumbnails.compactMap { $0 }.count) valid images")
            } catch {
                logger.error("trim: thumbnail generation failed: \(error.localizedDescription)")
            }
        }
    }
}