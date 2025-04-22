import SwiftUI
import AVFoundation
import AVKit

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