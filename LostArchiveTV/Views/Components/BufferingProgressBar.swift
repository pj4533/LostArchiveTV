//
//  BufferingProgressBar.swift
//  LostArchiveTV
//
//  Created by Claude on 2025-06-28.
//

import SwiftUI

struct BufferingProgressBar: View {
    let videoTitle: String
    let bufferProgress: Double
    let bufferSeconds: Double
    let bufferState: BufferState
    let isActivelyBuffering: Bool
    let bufferFillRate: Double
    let showReadinessMarker: Bool
    
    // Animation states
    @State private var pulseAnimation = false
    @State private var dotOpacity: Double = 1.0
    
    // Constants
    private let barHeight: CGFloat = 4
    private let cornerRadius: CGFloat = 2
    private let readinessThreshold: Double = 0.15
    private let textFontSize: CGFloat = 9
    private let iconFontSize: CGFloat = 8
    
    var body: some View {
        VStack(spacing: 2) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: barHeight)
                    
                    // Buffer fill with gradient
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(gradientForState)
                        .frame(width: geometry.size.width * bufferProgress, height: barHeight)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: bufferProgress)
                    
                    // Readiness marker at 15%
                    if showReadinessMarker {
                        readinessMarkerView
                            .position(x: geometry.size.width * readinessThreshold, y: barHeight / 2)
                    }
                    
                    // Pulsing dot at buffer position when downloading
                    if isActivelyBuffering && bufferProgress > 0 && bufferProgress < 1 {
                        pulsingDotView
                            .position(x: geometry.size.width * bufferProgress, y: barHeight / 2)
                    }
                }
            }
            .frame(height: barHeight)
            
            // Text overlay
            HStack(spacing: 4) {
                // Video title (truncated)
                Text(videoTitle)
                    .font(.system(size: textFontSize))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Buffer duration
                Text(String(format: "%.1fs", bufferSeconds))
                    .font(.system(size: textFontSize, design: .monospaced))
                    .foregroundColor(colorForState.opacity(0.9))
                
                // Fill rate arrow
                if bufferFillRate != 0 {
                    Image(systemName: bufferFillRate > 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: iconFontSize))
                        .foregroundColor(bufferFillRate > 0 ? .green : .red)
                        .opacity(0.8)
                }
                
                // Network activity icon
                if isActivelyBuffering {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: iconFontSize))
                        .foregroundColor(.white.opacity(0.6))
                        .symbolEffect(.pulse)
                }
            }
        }
        .onAppear {
            startPulsingAnimation()
        }
    }
    
    // MARK: - Computed Properties
    
    private var colorForState: Color {
        switch bufferState {
        case .unknown:
            return .gray
        case .empty:
            return .red
        case .critical:
            return .red.opacity(0.8)
        case .low:
            return .orange
        case .sufficient:
            return .yellow
        case .good:
            return .green.opacity(0.7)
        case .excellent:
            return .green
        }
    }
    
    private var gradientForState: LinearGradient {
        let baseColor = colorForState
        return LinearGradient(
            gradient: Gradient(colors: [
                baseColor.opacity(0.8),
                baseColor,
                baseColor.opacity(0.8)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // MARK: - Subviews
    
    private var readinessMarkerView: some View {
        HStack(spacing: 1) {
            // Triangle pointing right
            Path { path in
                path.move(to: CGPoint(x: 0, y: 3))
                path.addLine(to: CGPoint(x: 5, y: 0))
                path.addLine(to: CGPoint(x: 0, y: -3))
                path.closeSubpath()
            }
            .fill(Color.white.opacity(0.6))
            .frame(width: 5, height: 6)
            
            // Vertical line
            Rectangle()
                .fill(Color.white.opacity(0.6))
                .frame(width: 1, height: 8)
        }
    }
    
    private var pulsingDotView: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 6, height: 6)
            .opacity(dotOpacity)
            .scaleEffect(pulseAnimation ? 1.2 : 0.8)
            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulseAnimation)
    }
    
    // MARK: - Methods
    
    private func startPulsingAnimation() {
        withAnimation {
            pulseAnimation = true
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black
        
        VStack(spacing: 20) {
            // Different buffer states
            BufferingProgressBar(
                videoTitle: "Amazing Archive Video - Episode 1",
                bufferProgress: 0.05,
                bufferSeconds: 1.5,
                bufferState: .critical,
                isActivelyBuffering: true,
                bufferFillRate: -0.5,
                showReadinessMarker: true
            )
            
            BufferingProgressBar(
                videoTitle: "Documentary: The History of Computing",
                bufferProgress: 0.25,
                bufferSeconds: 7.5,
                bufferState: .low,
                isActivelyBuffering: true,
                bufferFillRate: 1.2,
                showReadinessMarker: true
            )
            
            BufferingProgressBar(
                videoTitle: "Classic TV Show",
                bufferProgress: 0.6,
                bufferSeconds: 18.0,
                bufferState: .sufficient,
                isActivelyBuffering: false,
                bufferFillRate: 0,
                showReadinessMarker: true
            )
            
            BufferingProgressBar(
                videoTitle: "Educational Content - Very Long Title That Should Be Truncated",
                bufferProgress: 0.85,
                bufferSeconds: 25.5,
                bufferState: .good,
                isActivelyBuffering: true,
                bufferFillRate: 2.5,
                showReadinessMarker: false
            )
            
            BufferingProgressBar(
                videoTitle: "Premium Content",
                bufferProgress: 1.0,
                bufferSeconds: 45.0,
                bufferState: .excellent,
                isActivelyBuffering: false,
                bufferFillRate: 0,
                showReadinessMarker: false
            )
        }
        .padding()
    }
}