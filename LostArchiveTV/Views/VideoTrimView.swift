import SwiftUI
import AVFoundation
import AVKit

struct VideoTrimView: View {
    @ObservedObject var viewModel: VideoTrimViewModel
    @Environment(\.dismiss) private var dismiss
    
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
                                // Play/pause button overlay
                                Button(action: viewModel.togglePlayback) {
                                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.white)
                                        .shadow(radius: 3)
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
                                    // Show actual thumbnails
                                    HStack(spacing: 0) {
                                        ForEach(0..<viewModel.thumbnails.count, id: \.self) { index in
                                            if let uiImage = viewModel.thumbnails[index] {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: timelineWidth / CGFloat(viewModel.thumbnails.count), height: thumbnailHeight)
                                                    .clipped()
                                            }
                                        }
                                    }
                                    .frame(height: thumbnailHeight)
                                }
                            }
                            
                            // Calculate positions for visualization
                            let startPos = calculatePosition(time: viewModel.startTrimTime, in: timelineWidth)
                            let endPos = calculatePosition(time: viewModel.endTrimTime, in: timelineWidth)
                            let currentPos = calculatePosition(time: viewModel.currentTime, in: timelineWidth)
                            let selectedWidth = max(0, endPos - startPos)
                            
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
                            
                            // Left trim handle
                            TrimHandle(isDragging: .constant(false), orientation: .left)
                                .position(x: startPos, y: thumbnailHeight/2)
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            let positionRatio = max(0, min(value.location.x / timelineWidth, 0.95))
                                            let newTime = CMTime(seconds: viewModel.assetDuration.seconds * positionRatio, 
                                                              preferredTimescale: 600)
                                            viewModel.updateStartTrimTime(newTime)
                                        }
                                )
                                .zIndex(10) // Ensure handle is above other elements
                            
                            // Right trim handle
                            TrimHandle(isDragging: .constant(false), orientation: .right)
                                .position(x: endPos, y: thumbnailHeight/2)
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            let positionRatio = max(0.05, min(value.location.x / timelineWidth, 1.0))
                                            let newTime = CMTime(seconds: viewModel.assetDuration.seconds * positionRatio, 
                                                              preferredTimescale: 600)
                                            viewModel.updateEndTrimTime(newTime)
                                        }
                                )
                                .zIndex(10) // Ensure handle is above other elements
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let positionRatio = value.location.x / geo.size.width
                                    let newTime = CMTime(seconds: viewModel.assetDuration.seconds * positionRatio, 
                                                      preferredTimescale: 600)
                                    viewModel.seekToTime(newTime)
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
        .frame(width: 20, height: handleHeight) 
        .contentShape(Rectangle())
    }
}