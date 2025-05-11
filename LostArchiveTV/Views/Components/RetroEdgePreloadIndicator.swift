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
            return Color.cyan.opacity(0.8)
        case .preloaded:
            return Color.green.opacity(0.8)
        }
    }
    
    var secondaryColor: Color {
        switch self {
        case .notPreloading:
            return Color.clear
        case .preloading:
            return Color.blue.opacity(0.6)
        case .preloaded:
            return Color.green.opacity(0.6)
        }
    }
}

struct RetroEdgePreloadIndicator: View {
    let state: PreloadingState
    
    // Use an explicit animation value that we can control precisely
    @State private var animationPhase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Only show the animation when preloading or preloaded
                if state != .notPreloading {
                    Group {
                        if state == .preloading {
                            // Direct animated view
                            AnimatedBorderView(width: geometry.size.width, 
                                             height: geometry.size.height,
                                             color: state.color,
                                             secondaryColor: state.secondaryColor)
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
    
    private func preloadedBorder(size: CGSize) -> some View {
        ZStack {
            // Static glowing border
            EdgeBorder(width: 2.5)
                .stroke(state.color, lineWidth: 2.5)
                .blur(radius: 2.0)
                .opacity(0.9)
            
            // Green indicator dot in the corner
            VStack {
                HStack {
                    Spacer()
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                        .blur(radius: 1.5)
                        .opacity(1.0)
                        .padding(12)
                }
                Spacer()
            }
        }
    }
}

// Dedicated animated view that handles its own animation lifecycle
struct AnimatedBorderView: View {
    let width: CGFloat
    let height: CGFloat
    let color: Color
    let secondaryColor: Color
    
    // Animation controls
    @State private var pulsing = false
    
    var body: some View {
        // We use the timelineView with direct state animations
        ZStack {
            // Primary glow - directly animating properties
            EdgeBorder(width: pulsing ? 4.5 : 1.0)
                .stroke(color, lineWidth: pulsing ? 4.5 : 1.0)
                .blur(radius: pulsing ? 6.0 : 1.0)
                .opacity(pulsing ? 0.9 : 0.3)
            
            // Secondary inner glow for depth effect
            EdgeBorder(width: pulsing ? 2.5 : 0.5)
                .stroke(secondaryColor, lineWidth: pulsing ? 3.5 : 0.7)
                .blur(radius: pulsing ? 4.0 : 0.7)
                .opacity(pulsing ? 0.8 : 0.2)
        }
        .onAppear {
            // Start rapid cycling animation when view appears
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
    }
}

// Custom shape to draw only the edge border
struct EdgeBorder: Shape {
    let width: CGFloat
    
    // Add animation support
    var animatableData: CGFloat {
        get { width }
        set { }  // Read-only, just for animation
    }
    
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