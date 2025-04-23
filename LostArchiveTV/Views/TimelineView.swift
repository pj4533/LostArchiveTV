import SwiftUI
import AVFoundation

/// A view that displays a video timeline with thumbnails and draggable trim handles
struct TimelineView: View {
    @ObservedObject var viewModel: VideoTrimViewModel
    let timelineWidth: CGFloat
    let thumbnailHeight: CGFloat = 50
    
    var body: some View {
        ZStack(alignment: .center) {
            // Calculate window times
            let timeWindow = viewModel.calculateVisibleTimeWindow()
            
            // Render thumbnails if available
            Group {
                if viewModel.thumbnails.isEmpty {
                    // Show placeholder until thumbnails load
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: thumbnailHeight)
                } else {
                    // Create a ZStack for more precise thumbnail positioning
                    ZStack {
                        // Base background for thumbnails
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: thumbnailHeight)
                        
                        // Calculate visible window parameters
                        let visibleDuration = timeWindow.end - timeWindow.start
                        
                        // Only process thumbnails that would be visible
                        ForEach(0..<viewModel.thumbnails.count, id: \.self) { index in
                            if let uiImage = viewModel.thumbnails[index] {
                                // Calculate the time position for this thumbnail
                                let thumbTimeRatio = Double(index) / Double(viewModel.thumbnails.count - 1)
                                let thumbTime = viewModel.assetDuration.seconds * thumbTimeRatio
                                
                                // Only show thumbnails in the visible window
                                if thumbTime >= timeWindow.start && thumbTime <= timeWindow.end {
                                    // Calculate thumbnail position
                                    let relativePosition = (thumbTime - timeWindow.start) / visibleDuration
                                    let xPosition = CGFloat(relativePosition) * timelineWidth
                                    
                                    // Calculate thumbnail width
                                    let thumbsPerVisibleWindow = Double(viewModel.thumbnails.count) * (visibleDuration / viewModel.assetDuration.seconds)
                                    let approxWidth = timelineWidth / CGFloat(thumbsPerVisibleWindow)
                                    
                                    // Ensure we don't have gaps by making thumbnails slightly wider
                                    let thumbnailWidth = approxWidth * 1.1
                                    
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
            
            // Get handle positions from view model
            let startPos = viewModel.timeToPosition(timeInSeconds: viewModel.startTrimTime.seconds, timelineWidth: timelineWidth)
            let endPos = viewModel.timeToPosition(timeInSeconds: viewModel.endTrimTime.seconds, timelineWidth: timelineWidth)
            let selectedWidth = endPos - startPos
            let currentPos = viewModel.timeToPosition(timeInSeconds: viewModel.currentTime.seconds, timelineWidth: timelineWidth)
            
            // Current time indicator (playhead)
            Rectangle()
                .fill(Color.white)
                .frame(width: 2, height: thumbnailHeight)
                .position(x: currentPos, y: thumbnailHeight / 2)
            
            // Left non-selected area overlay
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .frame(width: startPos, height: thumbnailHeight)
                .position(x: startPos/2, y: thumbnailHeight/2)
            
            // Right non-selected area overlay
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .frame(width: max(0, timelineWidth - endPos), height: thumbnailHeight)
                .position(x: (timelineWidth + endPos)/2, y: thumbnailHeight/2)
            
            // Selected area border
            Rectangle()
                .fill(Color.clear)
                .border(Color.white, width: 2)
                .frame(width: selectedWidth, height: thumbnailHeight)
                .position(x: startPos + selectedWidth/2, y: thumbnailHeight/2)
            
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