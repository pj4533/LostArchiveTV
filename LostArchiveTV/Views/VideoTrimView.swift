import SwiftUI
import AVFoundation
import AVKit

struct VideoTrimView: View {
    @ObservedObject var viewModel: VideoTrimViewModel
    @Environment(\.dismiss) private var dismiss
    
    // State to track dragging to prevent zoom recalculation during drag
    @State private var isDraggingLeftHandle = false
    @State private var isDraggingRightHandle = false
    @State private var frozenVisibleStartRatio: Double = 0
    @State private var frozenVisibleDuration: Double = 0
    
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
                                    // Calculate zoom parameters
                                    let startRatio = viewModel.startTrimTime.seconds / viewModel.assetDuration.seconds
                                    let endRatio = viewModel.endTrimTime.seconds / viewModel.assetDuration.seconds
                                    
                                    // Add padding to show more context on either side (like TikTok)
                                    let paddingRatio = 0.15 // 15% padding on each side
                                    let visibleStartRatio = max(0, startRatio - paddingRatio)
                                    let visibleEndRatio = min(1, endRatio + paddingRatio)
                                    let visibleDuration = visibleEndRatio - visibleStartRatio
                                    
                                    // Calculate the zoom factor
                                    let zoomFactor = 1.0 / visibleDuration
                                    
                                    // Create a zoomed view of the thumbnails
                                    ZStack(alignment: .leading) {
                                        // Container for all thumbnails
                                        HStack(spacing: 0) {
                                            ForEach(0..<viewModel.thumbnails.count, id: \.self) { index in
                                                if let uiImage = viewModel.thumbnails[index] {
                                                    Image(uiImage: uiImage)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                        .frame(
                                                            width: (timelineWidth / CGFloat(viewModel.thumbnails.count)) * zoomFactor,
                                                            height: thumbnailHeight
                                                        )
                                                        .clipped()
                                                }
                                            }
                                        }
                                        .frame(height: thumbnailHeight)
                                        // Offset to show the visible section
                                        .offset(x: -timelineWidth * visibleStartRatio * zoomFactor)
                                    }
                                    .frame(width: timelineWidth, height: thumbnailHeight)
                                    .clipped()
                                }
                            }
                            
                            // Calculate the zoom parameters (should match the thumbnail calculations)
                            let startRatio = viewModel.startTrimTime.seconds / viewModel.assetDuration.seconds
                            let endRatio = viewModel.endTrimTime.seconds / viewModel.assetDuration.seconds
                            let paddingRatio = 0.15 // 15% padding on each side
                            let visibleStartRatio = max(0, startRatio - paddingRatio)
                            let visibleEndRatio = min(1, endRatio + paddingRatio)
                            let visibleDuration = visibleEndRatio - visibleStartRatio
                            
                            // Calculate the zoom factor and visible width
                            let zoomFactor = 1.0 / visibleDuration
                            
                            // Calculate position in the zoomed timeline
                            // Formula: (actual ratio - visible start ratio) * zoom factor * timeline width
                            let startPosRatio = (startRatio - visibleStartRatio) / visibleDuration
                            let endPosRatio = (endRatio - visibleStartRatio) / visibleDuration
                            let currentTimeRatio = (viewModel.currentTime.seconds / viewModel.assetDuration.seconds - visibleStartRatio) / visibleDuration
                            
                            // Convert to actual positions
                            let startPos = timelineWidth * startPosRatio
                            let endPos = timelineWidth * endPosRatio
                            let selectedWidth = endPos - startPos
                            
                            // Calculate current playhead position
                            let currentPos = timelineWidth * currentTimeRatio
                            
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
                            TrimHandle(isDragging: .constant(false), orientation: .left)
                                .position(x: startPos, y: thumbnailHeight/2)
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            handleLeftDrag(value, timelineWidth: timelineWidth, zoomFactor: zoomFactor)
                                        }
                                )
                                .zIndex(10) // Ensure handle is above other elements
                            
                            // Right trim handle - fixed at right edge in TikTok style
                            TrimHandle(isDragging: .constant(false), orientation: .right)
                                .position(x: endPos, y: thumbnailHeight/2)
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            handleRightDrag(value, timelineWidth: timelineWidth, zoomFactor: zoomFactor)
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
        // Use the direct drag translation without recalculating the zoom
        // This will move handles independently of each other
        let translation = value.translation.width
        
        // Convert translation to video time delta (considering zoom factor)
        let timePerPixel = viewModel.assetDuration.seconds / timelineWidth / zoomFactor
        let timeChange = translation * timePerPixel
        
        // Calculate new time by adjusting from the original position
        let originalStartSeconds = viewModel.startTrimTime.seconds
        let newSeconds = originalStartSeconds + timeChange
        
        // Apply constraints
        let minimumDuration = 1.0 // 1 second minimum
        let maxStartTime = viewModel.endTrimTime.seconds - minimumDuration
        let clampedTime = max(0, min(newSeconds, maxStartTime))
        
        // Update only the start time
        let newTime = CMTime(seconds: clampedTime, preferredTimescale: 600)
        viewModel.updateStartTrimTime(newTime)
    }
    
    private func handleRightDrag(_ value: DragGesture.Value, timelineWidth: CGFloat, zoomFactor: Double) {
        // Use the direct drag translation without recalculating the zoom
        // This will move handles independently of each other
        let translation = value.translation.width
        
        // Convert translation to video time delta (considering zoom factor)
        let timePerPixel = viewModel.assetDuration.seconds / timelineWidth / zoomFactor
        let timeChange = translation * timePerPixel
        
        // Calculate new time by adjusting from the original position
        let originalEndSeconds = viewModel.endTrimTime.seconds
        let newSeconds = originalEndSeconds + timeChange
        
        // Apply constraints
        let minimumDuration = 1.0 // 1 second minimum
        let minEndTime = viewModel.startTrimTime.seconds + minimumDuration
        let clampedTime = min(viewModel.assetDuration.seconds, max(newSeconds, minEndTime))
        
        // Update only the end time
        let newTime = CMTime(seconds: clampedTime, preferredTimescale: 600)
        viewModel.updateEndTrimTime(newTime)
    }
    
    private func handleTimelineScrub(_ value: DragGesture.Value, geometry: GeometryProxy, visibleStartRatio: Double, visibleDuration: Double) {
        // Direct positioning within the zoomed timeline
        let locationInTimeline = value.location.x
        
        // Convert zoomed position to full video position
        let zoomedPositionRatio = max(0, min(locationInTimeline / geometry.size.width, 1.0))
        let fullVideoRatio = visibleStartRatio + (zoomedPositionRatio * visibleDuration)
        let timeInSeconds = viewModel.assetDuration.seconds * fullVideoRatio
        
        // Create and seek to the new time
        let newTime = CMTime(seconds: timeInSeconds, preferredTimescale: 600)
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