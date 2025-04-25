//
//  ThumbnailsContainer.swift
//  LostArchiveTV
//
//  Created by Claude on 4/25/25.
//

import SwiftUI
import AVFoundation

// Component for displaying video thumbnails in the timeline
struct ThumbnailsContainer: View {
    @ObservedObject var viewModel: VideoTrimViewModel
    let timeWindow: (start: Double, end: Double)
    let timelineWidth: CGFloat
    let thumbnailHeight: CGFloat
    
    var body: some View {
        ZStack {
            // Base background for thumbnails
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: thumbnailHeight)
            
            // Get visible window parameters for the zoomed view
            let visibleStart = timeWindow.start
            let visibleEnd = timeWindow.end
            let visibleDuration = visibleEnd - visibleStart
            
            // Calculate the visible ratio of the full timeline
            let fullDuration = viewModel.assetDuration.seconds
            let visibleRatio = visibleDuration / fullDuration
            
            // Process thumbnails
            ForEach(0..<viewModel.thumbnails.count, id: \.self) { index in
                if let uiImage = viewModel.thumbnails[index] {
                    // Calculate the time position for this thumbnail
                    let thumbTimeRatio = Double(index) / Double(viewModel.thumbnails.count - 1)
                    let thumbTime = fullDuration * thumbTimeRatio
                    
                    // Only show thumbnails in the visible window
                    if thumbTime >= visibleStart && thumbTime <= visibleEnd {
                        // Calculate position directly using view model's helper
                        let xPosition = viewModel.timeToPosition(timeInSeconds: thumbTime, timelineWidth: timelineWidth)
                        
                        // Calculate scaled thumbnail width based on visible ratio
                        // As we zoom in (smaller visibleRatio), thumbnails get wider
                        let scaleFactor = min(3.0, 1.0 / visibleRatio) // Limit scale to 3x
                        let thumbnailWidth = (timelineWidth / CGFloat(viewModel.thumbnails.count) / CGFloat(visibleRatio)) * 1.1
                        
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: thumbnailWidth, height: thumbnailHeight)
                            .position(x: xPosition, y: thumbnailHeight/2)
                    }
                }
            }
        }
        .frame(height: thumbnailHeight)
        .clipped()
    }
}