import SwiftUI
import AVFoundation

struct VideoTrimView: View {
    @ObservedObject var viewModel: VideoTrimViewModel
    @Environment(\.dismiss) private var dismiss
    
    // For tracking gesture states
    @State private var leftHandleDragOffset: CGFloat = 0
    @State private var rightHandleDragOffset: CGFloat = 0
    @State private var isDraggingLeftHandle = false
    @State private var isDraggingRightHandle = false
    @State private var isLongPressing = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Video Player
                TrimVideoPlayerView(viewModel: viewModel)
                    .aspectRatio(16/9, contentMode: .fit)
                    .padding(.bottom, 20)
                
                // Timeline Scrubber
                TimelineScrubber(viewModel: viewModel, 
                               leftHandleDragOffset: $leftHandleDragOffset,
                               rightHandleDragOffset: $rightHandleDragOffset,
                               isDraggingLeftHandle: $isDraggingLeftHandle,
                               isDraggingRightHandle: $isDraggingRightHandle,
                               isLongPressing: $isLongPressing)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Trim Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // First clean up resources
                        viewModel.prepareForDismissal()
                        
                        // Then dismiss the view
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.saveTrimmmedVideo()
                            // Clean up before dismiss
                            viewModel.prepareForDismissal()
                            dismiss()
                        }
                    }
                    .disabled(viewModel.isSaving)
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
        }
    }
}

// Video Player Component
struct TrimVideoPlayerView: View {
    @ObservedObject var viewModel: VideoTrimViewModel
    
    var body: some View {
        ZStack {
            VideoPlayerRepresentable(player: viewModel.player)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Play/Pause Button Overlay
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: viewModel.togglePlayback) {
                        Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                            .shadow(radius: 3)
                    }
                    Spacer()
                }
                Spacer()
            }
        }
    }
}

// UIViewRepresentable for AVPlayer
struct VideoPlayerRepresentable: UIViewRepresentable {
    var player: AVPlayer
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        view.layer.addSublayer(playerLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let playerLayer = uiView.layer.sublayers?.first as? AVPlayerLayer {
            playerLayer.frame = uiView.bounds
            playerLayer.player = player
        }
    }
}

// Timeline Scrubber Component
struct TimelineScrubber: View {
    @ObservedObject var viewModel: VideoTrimViewModel
    
    @Binding var leftHandleDragOffset: CGFloat
    @Binding var rightHandleDragOffset: CGFloat
    @Binding var isDraggingLeftHandle: Bool
    @Binding var isDraggingRightHandle: Bool
    @Binding var isLongPressing: Bool
    
    // Constants for UI
    private let handleWidth: CGFloat = 10
    private let timelineHeight: CGFloat = 40
    private let handleHeight: CGFloat = 60
    private let timelineColor = Color.yellow
    private let handleColor = Color.yellow
    private let borderWidth: CGFloat = 3
    
    // Computed properties for scale and position calculations
    private var totalDuration: Double {
        viewModel.assetDuration.seconds
    }
    
    private var trimmedDuration: Double {
        CMTimeSubtract(viewModel.endTrimTime, viewModel.startTrimTime).seconds
    }
    
    private var zoomedRatio: CGFloat {
        viewModel.isZoomed ? 3.0 : 1.0
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Timeline background
            Rectangle()
                .fill(Color.black.opacity(0.3))
                .frame(height: timelineHeight)
            
            // Play button
            Button(action: viewModel.togglePlayback) {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
            }
            .padding(.leading, -50)
            
            // Frame thumbnails would go here (simplified for now)
            Rectangle()
                .fill(Color.gray.opacity(0.5))
                .frame(height: timelineHeight)
            
            // Current time indicator
            GeometryReader { geo in
                let timelineWidth = geo.size.width
                let currentPosition = calculatePosition(time: viewModel.currentTime, in: timelineWidth)
                
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2, height: timelineHeight + 10)
                    .position(x: currentPosition, y: timelineHeight / 2)
            }
            
            // Trim handles and selection area
            GeometryReader { geo in
                let timelineWidth = geo.size.width
                
                ZStack {
                    // Calculate positions
                    let startPos = calculatePosition(time: viewModel.startTrimTime, in: timelineWidth)
                    let endPos = calculatePosition(time: viewModel.endTrimTime, in: timelineWidth)
                    let selectedWidth = max(0, endPos - startPos)
                    
                    // Selected area
                    Rectangle()
                        .fill(Color.clear)
                        .border(timelineColor, width: borderWidth)
                        .frame(width: selectedWidth, height: timelineHeight)
                        .position(x: startPos + selectedWidth / 2, y: timelineHeight / 2)
                    
                    // Left handle
                    TrimmingHandle(isDragging: $isDraggingLeftHandle, 
                                 handleColor: handleColor,
                                 orientation: .left)
                        .position(x: startPos, y: timelineHeight / 2)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isDraggingLeftHandle = true
                                    let delta = value.translation.width
                                    let positionRatio = delta / timelineWidth
                                    let timeDelta = positionRatio * totalDuration
                                    let newStartTime = CMTime(seconds: viewModel.startTrimTime.seconds + timeDelta, 
                                                             preferredTimescale: viewModel.startTrimTime.timescale)
                                    viewModel.updateStartTrimTime(newStartTime)
                                    leftHandleDragOffset = delta
                                }
                                .onEnded { _ in
                                    isDraggingLeftHandle = false
                                    leftHandleDragOffset = 0
                                }
                        )
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.5)
                                .onEnded { _ in
                                    viewModel.toggleZoom()
                                    isLongPressing = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isLongPressing = false
                                    }
                                }
                        )
                    
                    // Right handle
                    TrimmingHandle(isDragging: $isDraggingRightHandle, 
                                 handleColor: handleColor,
                                 orientation: .right)
                        .position(x: endPos, y: timelineHeight / 2)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isDraggingRightHandle = true
                                    let delta = value.translation.width
                                    let positionRatio = delta / timelineWidth
                                    let timeDelta = positionRatio * totalDuration
                                    let newEndTime = CMTime(seconds: viewModel.endTrimTime.seconds + timeDelta, 
                                                           preferredTimescale: viewModel.endTrimTime.timescale)
                                    viewModel.updateEndTrimTime(newEndTime)
                                    rightHandleDragOffset = delta
                                }
                                .onEnded { _ in
                                    isDraggingRightHandle = false
                                    rightHandleDragOffset = 0
                                }
                        )
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.5)
                                .onEnded { _ in
                                    viewModel.toggleZoom()
                                    isLongPressing = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isLongPressing = false
                                    }
                                }
                        )
                }
            }
        }
        .frame(height: handleHeight)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isZoomed)
    }
    
    private func calculatePosition(time: CMTime, in width: CGFloat) -> CGFloat {
        let timePosition = (time.seconds - viewModel.startOffsetTime.seconds) / totalDuration
        
        // Apply zoom if active
        if viewModel.isZoomed {
            let zoomedTimePosition = timePosition * zoomedRatio
            return min(max(0, width * zoomedTimePosition), width)
        } else {
            return min(max(0, width * timePosition), width)
        }
    }
}

// Trim Handle Component
struct TrimmingHandle: View {
    @Binding var isDragging: Bool
    var handleColor: Color
    var orientation: HandleOrientation
    
    enum HandleOrientation {
        case left
        case right
    }
    
    private let handleWidth: CGFloat = 10
    private let handleHeight: CGFloat = 60
    
    var body: some View {
        ZStack {
            // Handle bar
            Rectangle()
                .fill(handleColor)
                .frame(width: handleWidth, height: handleHeight)
                .cornerRadius(3)
            
            // Handle grip (visual indicator)
            VStack(spacing: 6) {
                ForEach(0..<4) { _ in
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2, height: 2)
                }
            }
        }
        .scaleEffect(isDragging ? 1.2 : 1.0)
        .animation(.spring(), value: isDragging)
    }
}