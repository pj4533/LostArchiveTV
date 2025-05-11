import SwiftUI

enum PreloadingState {
    case notPreloading
    case preloading
    case preloaded
    
    var color: Color {
        switch self {
        case .notPreloading:
            return Color.clear
        case .preloading:
            return Color.cyan.opacity(0.7)
        case .preloaded:
            return Color.green.opacity(0.7)
        }
    }
}

struct RetroEdgePreloadIndicator: View {
    let state: PreloadingState
    
    @State private var animationPhase: Int = 0
    
    // For edge glow effect
    private struct EdgeGlowPhase: Equatable {
        let glowWidth: CGFloat
        let opacity: Double
    }
    
    private let preloadingPhases: [EdgeGlowPhase] = [
        EdgeGlowPhase(glowWidth: 1.5, opacity: 0.5),
        EdgeGlowPhase(glowWidth: 2.0, opacity: 0.7),
        EdgeGlowPhase(glowWidth: 2.5, opacity: 0.9),
        EdgeGlowPhase(glowWidth: 2.0, opacity: 0.7),
        EdgeGlowPhase(glowWidth: 1.5, opacity: 0.5)
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Only show the animation when preloading or preloaded
                if state != .notPreloading {
                    Group {
                        if state == .preloading {
                            // Animated border when preloading
                            preloadingAnimation(size: geometry.size)
                        } else {
                            // Static border when preloaded with corner indicator
                            preloadedBorder(size: geometry.size)
                        }
                    }
                    .allowsHitTesting(false) // Make sure it doesn't interfere with touch events
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
    }
    
    private func preloadingAnimation(size: CGSize) -> some View {
        ZStack {
            // Animated edge glow
            PhaseAnimator(preloadingPhases, trigger: animationPhase) { phase in
                EdgeBorder(width: phase.glowWidth)
                    .stroke(state.color, lineWidth: phase.glowWidth)
                    .opacity(phase.opacity)
                    .blur(radius: 2.0)
            } animation: { phase in
                .easeInOut(duration: 1.5)
            }
            
            // Add a subtle neon glow flowing around the border
            EdgeFlowAnimation(state: state)
        }
        .onAppear {
            // Continuously update the animation phase to keep it flowing
            Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                animationPhase += 1
            }
        }
    }
    
    private func preloadedBorder(size: CGSize) -> some View {
        ZStack {
            // Static glowing border
            EdgeBorder(width: 2.0)
                .stroke(state.color, lineWidth: 2.0)
                .blur(radius: 1.5)
                .opacity(0.8)
            
            // Green indicator dot in the corner
            VStack {
                HStack {
                    Spacer()
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .blur(radius: 1.0)
                        .opacity(0.9)
                        .padding(12)
                }
                Spacer()
            }
        }
    }
}

// Custom shape to draw only the edge border
struct EdgeBorder: Shape {
    let width: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Outer rectangle
        path.addRect(rect)
        
        // Inner rectangle (to create a border effect)
        let innerRect = rect.insetBy(dx: width, dy: width)
        path.addRect(innerRect)
        
        return path
    }
}

// Animation that flows around the edges
struct EdgeFlowAnimation: View {
    let state: PreloadingState
    @State private var rotation: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Flowing dots that move along the border
                ForEach(0..<4) { i in
                    Circle()
                        .fill(state.color)
                        .frame(width: 4, height: 4)
                        .blur(radius: 2)
                        .opacity(0.8)
                        .offset(
                            x: flowOffset(index: i, size: geometry.size).x,
                            y: flowOffset(index: i, size: geometry.size).y
                        )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .onAppear {
                withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
        }
    }
    
    private func flowOffset(index: Int, size: CGSize) -> CGPoint {
        let width = size.width
        let height = size.height
        let perimeter = 2 * (width + height)
        let offset = CGFloat(index) * perimeter / 4 + (perimeter * rotation / 360)
        let normalizedOffset = offset.truncatingRemainder(dividingBy: perimeter)
        
        if normalizedOffset < width {
            // Top edge
            return CGPoint(x: normalizedOffset, y: 0)
        } else if normalizedOffset < width + height {
            // Right edge
            return CGPoint(x: width, y: normalizedOffset - width)
        } else if normalizedOffset < 2 * width + height {
            // Bottom edge
            return CGPoint(x: width - (normalizedOffset - width - height), y: height)
        } else {
            // Left edge
            return CGPoint(x: 0, y: height - (normalizedOffset - 2 * width - height))
        }
    }
}

#Preview {
    ZStack {
        Color.black
        Text("Video Content")
            .font(.largeTitle)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        
        RetroEdgePreloadIndicator(state: .preloading)
    }
}