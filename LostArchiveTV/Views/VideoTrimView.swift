import SwiftUI
import AVFoundation
import AVKit

struct VideoTrimView: View {
    @ObservedObject var viewModel: VideoTrimViewModel
    @Environment(\.dismiss) private var dismiss
    
    // State to track dragging to prevent zoom recalculation during drag
    // Simple state tracking for drags
    @State private var isDraggingLeftHandle = false
    @State private var isDraggingRightHandle = false
    @State private var dragStartPos: CGFloat = 0
    @State private var initialHandleTime: Double = 0
    
    // Constants for UI layout
    private let handleWidth: CGFloat = 8
    private let thumbnailHeight: CGFloat = 50
    private let timelineHeight: CGFloat = 50
    
    var body: some View {
        ZStack {
            // Background color
            Color.black.edgesIgnoringSafeArea(.all)
            
            if viewModel.isLoading {
                // Download progress view
                VStack {
                    Text("Preparing video for trimming")
                        .foregroundColor(.white)
                        .padding(.bottom, 10)
                    
                    ProgressView(value: viewModel.downloadProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(width: 200)
                        .tint(Color.white)
                    
                    Text("\(Int(viewModel.downloadProgress * 100))%")
                        .foregroundColor(.white)
                        .padding(.top, 8)
                }
            } else {
                VStack(spacing: 0) {
                    // Top toolbar
                    HStack {
                        Button("Cancel") {
                            // Clean up resources
                            viewModel.prepareForDismissal()
                            dismiss()
                        }
                        .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("Adjust clip")
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button("Save") {
                            Task {
                                await viewModel.saveTrimmmedVideo()
                                // Clean up resources
                                viewModel.prepareForDismissal()
                                dismiss()
                            }
                        }
                        .foregroundColor(.white)
                        .disabled(viewModel.isSaving)
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Video player in center (larger space)
                    ZStack {
                        // Video player using SwiftUI VideoPlayer
                        VideoPlayer(player: viewModel.player)
                            .aspectRatio(9/16, contentMode: ContentMode.fit)
                            .frame(maxWidth: .infinity)
                            .background(Color.black)
                            .overlay(
                                // Play/pause button overlay - larger and more prominent
                                Button(action: viewModel.togglePlayback) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.black.opacity(0.3))
                                            .frame(width: 80, height: 80)
                                        
                                        Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                            .font(.system(size: 50))
                                            .foregroundColor(.white)
                                            .shadow(radius: 3)
                                    }
                                }
                            )
                    }
                    
                    Spacer()
                    
                    // Duration text
                    HStack {
                        Text(formatTime(viewModel.startTrimTime.seconds))
                            .font(.caption)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("\(formatDuration(from: viewModel.startTrimTime, to: viewModel.endTrimTime)) selected")
                            .font(.footnote)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text(formatTime(viewModel.endTrimTime.seconds))
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                    
                    // Timeline scrubber at bottom
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Calculate the timeline width for this view
                            let timelineWidth = geo.size.width
                            
                            // Video thumbnails background
                            Group {
                                if viewModel.thumbnails.isEmpty {
                                    // Show placeholder until thumbnails load
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(height: thumbnailHeight)
                                } else {
                                    // SIMPLIFIED APPROACH:
                                    // 1. Show a fixed 90-second window (or less if video is shorter)
                                    // 2. Center around the selected portion with padding
                                    // 3. No dynamic zooming when handles move
                                    
                                    // Calculate how much time we want to show in the timeline
                                    let windowDuration = min(90.0, viewModel.assetDuration.seconds) // Show 90 seconds or entire video
                                    
                                    // Calculate the middle of the trimmed section
                                    let trimMiddle = (viewModel.startTrimTime.seconds + viewModel.endTrimTime.seconds) / 2.0
                                    
                                    // Calculate the start time of our visible window (centered on the trim)
                                    let timelineStart = max(0, trimMiddle - windowDuration / 2)
                                    let timelineEnd = min(viewModel.assetDuration.seconds, timelineStart + windowDuration)
                                    
                                    // Adjust to make sure we don't go out of bounds
                                    let adjustedTimelineStart = min(timelineStart, viewModel.assetDuration.seconds - windowDuration)
                                    let adjustedTimelineEnd = adjustedTimelineStart + windowDuration
                                    
                                    // Calculate pixels per second for the timeline
                                    let pixelsPerSecond = timelineWidth / windowDuration
                                    
                                    // Create the thumbnails view with our fixed window
                                    ZStack(alignment: .leading) {
                                        // Container for all thumbnails
                                        HStack(spacing: 0) {
                                            ForEach(0..<viewModel.thumbnails.count, id: \.self) { index in
                                                if let uiImage = viewModel.thumbnails[index] {
                                                    // Calculate the time position for this thumbnail
                                                    let thumbTimeRatio = Double(index) / Double(viewModel.thumbnails.count)
                                                    let thumbTime = viewModel.assetDuration.seconds * thumbTimeRatio
                                                    
                                                    // Only show thumbnails within our window
                                                    if thumbTime >= adjustedTimelineStart && thumbTime <= adjustedTimelineEnd {
                                                        let position = (thumbTime - adjustedTimelineStart) * pixelsPerSecond
                                                        Image(uiImage: uiImage)
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fill)
                                                            .frame(
                                                                width: timelineWidth / CGFloat(windowDuration / (viewModel.assetDuration.seconds / Double(viewModel.thumbnails.count))),
                                                                height: thumbnailHeight
                                                            )
                                                            .clipped()
                                                    }
                                                }
                                            }
                                        }
                                        .frame(height: thumbnailHeight)
                                    }
                                    .frame(width: timelineWidth, height: thumbnailHeight)
                                    .clipped()
                                }
                            }
                            
                            // SIMPLIFIED - Fixed time window calculations
                            // Calculate our fixed 90s window (or less if video is shorter)
                            let windowDuration = min(90.0, viewModel.assetDuration.seconds)
                            
                            // Calculate the middle of the trimmed section
                            let trimMiddle = (viewModel.startTrimTime.seconds + viewModel.endTrimTime.seconds) / 2.0
                            
                            // Calculate the start and end of our fixed visible window
                            let timelineStart = max(0, trimMiddle - windowDuration / 2)
                            let adjustedTimelineStart = min(timelineStart, viewModel.assetDuration.seconds - windowDuration)
                            let timelineEnd = min(adjustedTimelineStart + windowDuration, viewModel.assetDuration.seconds)
                            
                            // Calculate pixels per second - fixed scale
                            let pixelsPerSecond = timelineWidth / windowDuration
                            
                            // Calculate handle positions in pixels using simple linear mapping
                            let startPos = (viewModel.startTrimTime.seconds - adjustedTimelineStart) * pixelsPerSecond
                            let endPos = (viewModel.endTrimTime.seconds - adjustedTimelineStart) * pixelsPerSecond
                            let selectedWidth = endPos - startPos
                            
                            // Calculate current playhead position
                            let currentPos = (viewModel.currentTime.seconds - adjustedTimelineStart) * pixelsPerSecond
                            
                            // Current time indicator (vertical white line)
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: 2, height: thumbnailHeight + 20)
                                .position(x: currentPos, y: thumbnailHeight / 2)
                            
                            // Left non-selected area overlay
                            Rectangle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: startPos, height: thumbnailHeight)
                                .position(x: startPos/2, y: thumbnailHeight/2)
                            
                            // Right non-selected area overlay
                            Rectangle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: timelineWidth - endPos, height: thumbnailHeight)
                                .position(x: (timelineWidth + endPos)/2, y: thumbnailHeight/2)
                            
                            // Selected area border
                            Rectangle()
                                .fill(Color.clear)
                                .border(Color.white, width: 2)
                                .frame(width: selectedWidth, height: thumbnailHeight)
                                .position(x: startPos + selectedWidth/2, y: thumbnailHeight/2)
                            
                            // Left trim handle - fixed at left edge in TikTok style
                            TrimHandle(isDragging: $isDraggingLeftHandle, orientation: .left)
                                .position(x: startPos, y: thumbnailHeight/2)
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            handleLeftDrag(value, timelineWidth: timelineWidth, zoomFactor: 1.0)
                                        }
                                        .onEnded { _ in
                                            isDraggingLeftHandle = false
                                        }
                                )
                                .zIndex(10) // Ensure handle is above other elements
                            
                            // Right trim handle - fixed at right edge in TikTok style
                            TrimHandle(isDragging: $isDraggingRightHandle, orientation: .right)
                                .position(x: endPos, y: thumbnailHeight/2)
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            handleRightDrag(value, timelineWidth: timelineWidth, zoomFactor: 1.0)
                                        }
                                        .onEnded { _ in
                                            isDraggingRightHandle = false
                                        }
                                )
                                .zIndex(10) // Ensure handle is above other elements
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    // Calculate the scrubbing position directly
                                    let startRatio = viewModel.startTrimTime.seconds / viewModel.assetDuration.seconds
                                    let endRatio = viewModel.endTrimTime.seconds / viewModel.assetDuration.seconds
                                    let paddingRatio = 0.15 // Same as above
                                    
                                    let visibleStartRatio = max(0, startRatio - paddingRatio)
                                    let visibleEndRatio = min(1, endRatio + paddingRatio)
                                    let visibleDuration = visibleEndRatio - visibleStartRatio
                                    
                                    handleTimelineScrub(value, geometry: geo, visibleStartRatio: visibleStartRatio, visibleDuration: visibleDuration)
                                }
                        )
                    }
                    .frame(height: thumbnailHeight + 20)
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
        }
        .alert("Trim Error", isPresented: Binding<Bool>(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "Unknown error")
        }
        .onAppear {
            // Start downloading the video for trimming if needed
            Task {
                await viewModel.prepareForTrimming()
            }
        }
    }
    
    private func calculatePosition(time: CMTime, in width: CGFloat) -> CGFloat {
        let timePosition = time.seconds / viewModel.assetDuration.seconds
        return min(max(0, width * CGFloat(timePosition)), width)
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
    
    private func formatDuration(from start: CMTime, to end: CMTime) -> String {
        let durationSeconds = end.seconds - start.seconds
        return "\(String(format: "%.1f", durationSeconds))s"
    }
    
    // Handle drag methods to fix handle independence
    
    private func handleLeftDrag(_ value: DragGesture.Value, timelineWidth: CGFloat, zoomFactor: Double) {
        // Simple direct conversion from position to time
        let windowDuration = min(90.0, viewModel.assetDuration.seconds)
        let trimMiddle = (viewModel.startTrimTime.seconds + viewModel.endTrimTime.seconds) / 2.0
        let timelineStart = max(0, trimMiddle - windowDuration / 2)
        let adjustedTimelineStart = min(timelineStart, viewModel.assetDuration.seconds - windowDuration)
        let pixelsPerSecond = timelineWidth / windowDuration
        
        // When drag starts, store initial position and time
        if !isDraggingLeftHandle {
            isDraggingLeftHandle = true
            dragStartPos = value.startLocation.x
            initialHandleTime = viewModel.startTrimTime.seconds
        }
        
        // Calculate drag distance in pixels and convert to time
        let dragDelta = value.location.x - dragStartPos
        let timeDelta = dragDelta / pixelsPerSecond
        
        // Calculate new time
        let newStartTime = initialHandleTime + timeDelta
        
        // Apply constraints
        let minimumDuration = 1.0
        let maxStartTime = viewModel.endTrimTime.seconds - minimumDuration
        let clampedStartTime = max(0, min(newStartTime, maxStartTime))
        
        // Update ONLY the start time
        let newTime = CMTime(seconds: clampedStartTime, preferredTimescale: 600)
        viewModel.updateStartTrimTime(newTime)
    }
    
    private func handleRightDrag(_ value: DragGesture.Value, timelineWidth: CGFloat, zoomFactor: Double) {
        // Simple direct conversion from position to time
        let windowDuration = min(90.0, viewModel.assetDuration.seconds)
        let trimMiddle = (viewModel.startTrimTime.seconds + viewModel.endTrimTime.seconds) / 2.0
        let timelineStart = max(0, trimMiddle - windowDuration / 2)
        let adjustedTimelineStart = min(timelineStart, viewModel.assetDuration.seconds - windowDuration)
        let pixelsPerSecond = timelineWidth / windowDuration
        
        // When drag starts, store initial position and time
        if !isDraggingRightHandle {
            isDraggingRightHandle = true
            dragStartPos = value.startLocation.x
            initialHandleTime = viewModel.endTrimTime.seconds
        }
        
        // Calculate drag distance in pixels and convert to time
        let dragDelta = value.location.x - dragStartPos
        let timeDelta = dragDelta / pixelsPerSecond
        
        // Calculate new time
        let newEndTime = initialHandleTime + timeDelta
        
        // Apply constraints
        let minimumDuration = 1.0
        let minEndTime = viewModel.startTrimTime.seconds + minimumDuration
        let clampedEndTime = min(viewModel.assetDuration.seconds, max(newEndTime, minEndTime))
        
        // Update ONLY the end time
        let newTime = CMTime(seconds: clampedEndTime, preferredTimescale: 600)
        viewModel.updateEndTrimTime(newTime)
    }
    
    private func handleTimelineScrub(_ value: DragGesture.Value, geometry: GeometryProxy, visibleStartRatio: Double, visibleDuration: Double) {
        // Simple direct conversion from position to time using our fixed window
        let windowDuration = min(90.0, viewModel.assetDuration.seconds)
        let trimMiddle = (viewModel.startTrimTime.seconds + viewModel.endTrimTime.seconds) / 2.0
        let timelineStart = max(0, trimMiddle - windowDuration / 2)
        let adjustedTimelineStart = min(timelineStart, viewModel.assetDuration.seconds - windowDuration)
        
        // Convert screen position to time
        let locationInTimeline = value.location.x
        let pixelsPerSecond = geometry.size.width / windowDuration
        let positionRatio = max(0, min(locationInTimeline / geometry.size.width, 1.0))
        let timeInSeconds = adjustedTimelineStart + (positionRatio * windowDuration)
        
        // Create and seek to the new time
        let newTime = CMTime(seconds: min(timeInSeconds, viewModel.assetDuration.seconds), preferredTimescale: 600)
        viewModel.seekToTime(newTime)
    }
}

// Trim Handle Component
struct TrimHandle: View {
    @Binding var isDragging: Bool
    var orientation: HandleOrientation
    
    enum HandleOrientation {
        case left
        case right
    }
    
    private let handleWidth: CGFloat = 8
    private let handleHeight: CGFloat = 50
    
    var body: some View {
        ZStack {
            // Invisible larger touch area
            Rectangle()
                .fill(Color.clear)
                .frame(width: 44, height: handleHeight + 40) // Wider touch area
            
            // Handle bar
            Rectangle()
                .fill(Color.white)
                .frame(width: handleWidth, height: 50)
            
            // Top handle
            Circle()
                .fill(Color.white)
                .frame(width: 20, height: 20)
                .overlay(
                    Image(systemName: orientation == .left ? "chevron.left" : "chevron.right")
                        .foregroundColor(.black)
                        .font(.system(size: 10, weight: .bold))
                )
                .offset(y: -20)
            
            // Bottom handle
            Circle()
                .fill(Color.white)
                .frame(width: 20, height: 20)
                .overlay(
                    Image(systemName: orientation == .left ? "chevron.left" : "chevron.right")
                        .foregroundColor(.black)
                        .font(.system(size: 10, weight: .bold))
                )
                .offset(y: 20)
        }
        .frame(width: 44, height: handleHeight + 40) // Match the wider frame
        .contentShape(Rectangle())
    }
}

// Removed the ThumbnailStrip and TimelinePositionCalculator components since we're using direct positioning