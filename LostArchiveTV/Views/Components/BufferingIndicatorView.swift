//
//  BufferingIndicatorView.swift
//  LostArchiveTV
//
//  Created by Claude on 2025-06-28.
//

import SwiftUI

/// Container view that manages multiple BufferingProgressBar components
/// for comprehensive buffering indicator feature
struct BufferingIndicatorView: View {
    // MARK: - Properties
    
    let currentVideoMonitor: BufferingMonitor
    let nextVideoMonitor: BufferingMonitor?
    let currentVideoTitle: String
    let nextVideoTitle: String?
    
    // MARK: - Constants
    
    private let barSpacing: CGFloat = 8
    private let nextVideoOpacity: Double = 0.6
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: barSpacing) {
            // Current video progress bar
            BufferingProgressBar(
                videoTitle: currentVideoTitle,
                bufferProgress: currentVideoMonitor.bufferProgress,
                bufferSeconds: currentVideoMonitor.bufferSeconds,
                bufferState: currentVideoMonitor.bufferState,
                isActivelyBuffering: currentVideoMonitor.isActivelyBuffering,
                bufferFillRate: currentVideoMonitor.bufferFillRate,
                showReadinessMarker: true
            )
            
            // Next video progress bar (if available)
            if let nextMonitor = nextVideoMonitor,
               let nextTitle = nextVideoTitle {
                BufferingProgressBar(
                    videoTitle: nextTitle,
                    bufferProgress: nextMonitor.bufferProgress,
                    bufferSeconds: nextMonitor.bufferSeconds,
                    bufferState: nextMonitor.bufferState,
                    isActivelyBuffering: nextMonitor.isActivelyBuffering,
                    bufferFillRate: nextMonitor.bufferFillRate,
                    showReadinessMarker: true
                )
                .opacity(nextVideoOpacity)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .scale)
                ))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: nextVideoMonitor != nil)
    }
}

// MARK: - Preview

#Preview("Single Video") {
    ZStack {
        Color.black
        
        BufferingIndicatorView(
            currentVideoMonitor: {
                let monitor = BufferingMonitor()
                // In preview, we can't actually set these values since they're read-only
                // But in real usage, these would be populated by the monitor
                return monitor
            }(),
            nextVideoMonitor: nil,
            currentVideoTitle: "Amazing Archive Video - Episode 1",
            nextVideoTitle: nil
        )
        .padding()
    }
}

#Preview("Two Videos") {
    ZStack {
        Color.black
        
        BufferingIndicatorView(
            currentVideoMonitor: {
                let monitor = BufferingMonitor()
                return monitor
            }(),
            nextVideoMonitor: {
                let monitor = BufferingMonitor()
                return monitor
            }(),
            currentVideoTitle: "Current Video: Documentary",
            nextVideoTitle: "Next: Classic TV Show"
        )
        .padding()
    }
}

#Preview("Interactive") {
    struct InteractivePreview: View {
        @State private var showNextVideo = false
        
        var body: some View {
            ZStack {
                Color.black
                
                VStack {
                    BufferingIndicatorView(
                        currentVideoMonitor: BufferingMonitor(),
                        nextVideoMonitor: showNextVideo ? BufferingMonitor() : nil,
                        currentVideoTitle: "Current Video Playing",
                        nextVideoTitle: showNextVideo ? "Next Video in Queue" : nil
                    )
                    .padding()
                    
                    Spacer()
                    
                    Button(action: {
                        showNextVideo.toggle()
                    }) {
                        Text(showNextVideo ? "Hide Next Video" : "Show Next Video")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .padding()
                }
            }
        }
    }
    
    return InteractivePreview()
}