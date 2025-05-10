//
//  VideoTrimViewModel+Export.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import Foundation
import AVFoundation
import OSLog

// MARK: - Video Export
extension VideoTrimViewModel {
    /// Save the trimmed video
    func saveTrimmmedVideo() async -> Bool {
        isSaving = true
        
        // Stop playback
        if isPlaying {
            playbackManager.player?.pause()
            isPlaying = false
        }
        
        // Is a download in progress?
        if isLoading {
            self.error = NSError(domain: "VideoTrimming", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Please wait for the download to complete before saving"
            ])
            isSaving = false
            logger.warning("Attempted to save while still downloading")
            return false
        }
        
        // If localVideoURL is nil but we have assetURL, use that instead
        if localVideoURL == nil {
            logger.warning("localVideoURL is nil, using assetURL instead: \(self.assetURL.absoluteString)")
            localVideoURL = self.assetURL
        }
        
        // Check if we have a local file to trim
        guard let localURL = localVideoURL else {
            self.error = NSError(domain: "VideoTrimming", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Video download not complete. Please wait and try again."
            ])
            isSaving = false
            logger.error("Attempted to trim without a local file")
            return false
        }
        
        do {
            // Use the export service to handle the trim and save
            let success = try await exportService.exportAndSaveVideo(
                localFileURL: localURL, 
                startTime: startTrimTime, 
                endTime: endTrimTime
            )
            
            // Success! Show a success message in the view
            if success {
                logger.info("Video successfully saved to Photos")
                self.error = nil
                self.successMessage = "Video successfully saved to Photos!"
            }
            
            isSaving = false
            return success
            
        } catch {
            logger.error("Trim process failed: \(error.localizedDescription)")
            self.error = error
            isSaving = false
            return false
        }
    }
}