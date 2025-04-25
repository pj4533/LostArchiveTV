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