//
//  TimelineContent.swift
//  LostArchiveTV
//
//  Created by Claude on 4/25/25.
//

import SwiftUI
import AVFoundation

// Main content component for the timeline view
struct TimelineContent: View {
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