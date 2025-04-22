import SwiftUI
import AVFoundation
import AVKit

// MARK: - TimelineView Component
struct TimelineView: View {
    @ObservedObject var viewModel: VideoTrimViewModel
    let timelineWidth: CGFloat
    let thumbnailHeight: CGFloat = 50
    
    var body: some View {
        ZStack(alignment: .leading) {
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
                    // Create a simple container for all thumbnails
                    HStack(spacing: 0) {
                        ForEach(0..<viewModel.thumbnails.count, id: \.self) { index in
                            if let uiImage = viewModel.thumbnails[index] {
                                // Calculate the time position for this thumbnail
                                let thumbTimeRatio = Double(index) / Double(viewModel.thumbnails.count)
                                let thumbTime = viewModel.assetDuration.seconds * thumbTimeRatio
                                
                                // Check if it's in our visible window
                                if thumbTime >= timeWindow.start && thumbTime <= timeWindow.end {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(
                                            width: timelineWidth / CGFloat(viewModel.thumbnails.count),
                                            height: thumbnailHeight
                                        )
                                        .clipped()
                                }
                            }
                        }
                    }
                    .frame(height: thumbnailHeight)
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
        .frame(height: thumbnailHeight + 20)
        .clipped()
    }
}

// MARK: - TrimHandle Component
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
        .frame(width: 44, height: handleHeight + 40)
        .contentShape(Rectangle())
    }
}

// MARK: - Main VideoTrimView
struct VideoTrimView: View {
    @ObservedObject var viewModel: VideoTrimViewModel
    @Environment(\.dismiss) private var dismiss
    
    private let thumbnailHeight: CGFloat = 50
    
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
                    
                    // Video player
                    ZStack {
                        VideoPlayer(player: viewModel.player)
                            .aspectRatio(9/16, contentMode: ContentMode.fit)
                            .frame(maxWidth: .infinity)
                            .background(Color.black)
                            .overlay(
                                // Play/pause button overlay
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
                    
                    // Timeline view using our new component
                    GeometryReader { geo in
                        TimelineView(viewModel: viewModel, timelineWidth: geo.size.width)
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
    
    // Formatter utilities
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
    
    private func formatDuration(from start: CMTime, to end: CMTime) -> String {
        let durationSeconds = end.seconds - start.seconds
        return "\(String(format: "%.1f", durationSeconds))s"
    }
}