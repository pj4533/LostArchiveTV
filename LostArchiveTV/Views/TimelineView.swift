import SwiftUI
import AVFoundation

/// A view that displays a video timeline with thumbnails and draggable trim handles
struct TimelineView: View {
    @ObservedObject var viewModel: VideoTrimViewModel
    let timelineWidth: CGFloat
    let thumbnailHeight: CGFloat = 50
    
    var body: some View {
        TimelineContent(
            viewModel: viewModel,
            timelineWidth: timelineWidth,
            thumbnailHeight: thumbnailHeight
        )
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    viewModel.scrubTimeline(position: value.location.x, timelineWidth: timelineWidth)
                }
        )
        .frame(height: thumbnailHeight)
        .clipped()
    }
}

// Extracted component to break up the complex expression
private struct TimelineContent: View {
    @ObservedObject var viewModel: VideoTrimViewModel
    let timelineWidth: CGFloat
    let thumbnailHeight: CGFloat
    
    var body: some View {
        ZStack(alignment: .center) {
            // Calculate window times
            let timeWindow = viewModel.calculateVisibleTimeWindow()
            
            // Render thumbnails if available
            renderThumbnails(timeWindow: timeWindow)
            
            // Get handle positions from view model
            let startPos = viewModel.timeToPosition(timeInSeconds: viewModel.startTrimTime.seconds, timelineWidth: timelineWidth)
            let endPos = viewModel.timeToPosition(timeInSeconds: viewModel.endTrimTime.seconds, timelineWidth: timelineWidth)
            let selectedWidth = endPos - startPos
            let currentPos = viewModel.timeToPosition(timeInSeconds: viewModel.currentTime.seconds, timelineWidth: timelineWidth)
            
            // Current time indicator (playhead)
            renderPlayhead(position: currentPos)
            
            // Left non-selected area overlay
            renderLeftOverlay(position: startPos)
            
            // Right non-selected area overlay
            renderRightOverlay(position: endPos)
            
            // Selected area border
            renderSelectionBorder(startPos: startPos, width: selectedWidth)
            
            // Trim handles
            renderTrimHandles(startPos: startPos, endPos: endPos)
        }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func renderThumbnails(timeWindow: (start: Double, end: Double)) -> some View {
        Group {
            if viewModel.thumbnails.isEmpty {
                // Show placeholder until thumbnails load
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: thumbnailHeight)
            } else {
                ThumbnailsContainer(
                    viewModel: viewModel,
                    timeWindow: timeWindow,
                    timelineWidth: timelineWidth,
                    thumbnailHeight: thumbnailHeight
                )
            }
        }
    }
    
    private func renderPlayhead(position: CGFloat) -> some View {
        Rectangle()
            .fill(Color.white)
            .frame(width: 2, height: thumbnailHeight)
            .position(x: position, y: thumbnailHeight / 2)
    }
    
    private func renderLeftOverlay(position: CGFloat) -> some View {
        Rectangle()
            .fill(Color.black.opacity(0.5))
            .frame(width: position, height: thumbnailHeight)
            .position(x: position/2, y: thumbnailHeight/2)
    }
    
    private func renderRightOverlay(position: CGFloat) -> some View {
        Rectangle()
            .fill(Color.black.opacity(0.5))
            .frame(width: max(0, timelineWidth - position), height: thumbnailHeight)
            .position(x: (timelineWidth + position)/2, y: thumbnailHeight/2)
    }
    
    private func renderSelectionBorder(startPos: CGFloat, width: CGFloat) -> some View {
        Rectangle()
            .fill(Color.clear)
            .border(Color.white, width: 2)
            .frame(width: width, height: thumbnailHeight)
            .position(x: startPos + width/2, y: thumbnailHeight/2)
    }
    
    private func renderTrimHandles(startPos: CGFloat, endPos: CGFloat) -> some View {
        Group {
            // Left trim handle
            TrimHandle(isDragging: Binding(
                get: { viewModel.isDraggingLeftHandle },
                set: { _ in }
            ), orientation: .left)
                .position(x: startPos, y: thumbnailHeight/2)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !viewModel.isDraggingLeftHandle {
                                viewModel.startLeftHandleDrag(position: value.startLocation.x)
                            }
                            viewModel.updateLeftHandleDrag(currentPosition: value.location.x, timelineWidth: timelineWidth)
                        }
                        .onEnded { _ in
                            viewModel.endLeftHandleDrag()
                        }
                )
                .zIndex(10)
            
            // Right trim handle
            TrimHandle(isDragging: Binding(
                get: { viewModel.isDraggingRightHandle },
                set: { _ in }
            ), orientation: .right)
                .position(x: endPos, y: thumbnailHeight/2)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !viewModel.isDraggingRightHandle {
                                viewModel.startRightHandleDrag(position: value.startLocation.x)
                            }
                            viewModel.updateRightHandleDrag(currentPosition: value.location.x, timelineWidth: timelineWidth)
                        }
                        .onEnded { _ in
                            viewModel.endRightHandleDrag()
                        }
                )
                .zIndex(10)
        }
    }
}

// Further extracted component for thumbnails
private struct ThumbnailsContainer: View {
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