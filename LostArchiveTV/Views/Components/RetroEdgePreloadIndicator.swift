import SwiftUI
import Foundation
import OSLog
import UIKit

enum PreloadingState: Equatable {
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
    
    // Track previous state to detect transitions
    @State private var previousState: PreloadingState = .notPreloading
    
    // Control the transition effect
    @State private var isTransitioning = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Only show the animation when preloading or preloaded
                if state != .notPreloading {
                    Group {
                        if state == .preloading {
                            // Use the original pulsing border when in preloading state
                            AnimatedBorderView(
                                width: geometry.size.width,
                                height: geometry.size.height,
                                color: state.color,
                                secondaryColor: state.secondaryColor,
                                isTransitioning: isTransitioning
                            )
                        } else if state == .preloaded {
                            // Use the static border with corner indicator when preloaded
                            preloadedBorder(size: geometry.size)
                        }
                    }
                    .allowsHitTesting(false) // Make sure it doesn't interfere with touch events
                }
                
                // Add the transition overlay when transitioning
                if isTransitioning {
                    TransitionOverlay()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .onChange(of: state) { newValue in
                Logger.ui.debug("State changed from \(String(describing: previousState)) to \(String(describing: newValue))")
                
                // Detect preloading -> preloaded transition
                if previousState == .preloading && newValue == .preloaded {
                    Logger.ui.notice("🎉 Triggering pulse transition animation!")
                    startTransition()
                }
                
                // Always update the previous state
                previousState = newValue
            }
        }
        .ignoresSafeArea()
    }
    
    private func preloadedBorder(size: CGSize) -> some View {
        // Simple solid green border for preloaded state
        EdgeBorder(width: 2.5)
            .stroke(state.color, lineWidth: 2.5)
    }
    
    private func startTransition() {
        // Begin the transition
        isTransitioning = true
        
        // Log the transition start
        Logger.ui.debug("Starting transition animation")
        
        // End the transition after it completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isTransitioning = false
            Logger.ui.debug("Transition animation completed")
        }
    }
}

// The overlay that appears during transition
struct TransitionOverlay: View {
    @State private var scale: CGFloat = 0.1
    @State private var opacity: CGFloat = 1.0
    @State private var blurRadius: CGFloat = 0
    
    // Create a blend from blue to green
    @State private var animationProgress: CGFloat = 0.0
    
    var body: some View {
        ZStack {
            // Outer explosion
            EdgeBorderMask(width: 25)
                .fill(transitionColor)
                .blur(radius: 40)
                .opacity(opacity)
                .scaleEffect(scale)
            
            // Inner explosion
            EdgeBorderMask(width: 15)
                .fill(transitionSecondaryColor)
                .blur(radius: 30)
                .opacity(opacity * 0.9)
                .scaleEffect(scale * 0.9)
        }
        .onAppear {
            // Animate to full size quickly
            withAnimation(.easeOut(duration: 0.2)) {
                scale = 1.0
                blurRadius = 40
            }
            
            // Simultaneously animate the color transition
            withAnimation(.easeInOut(duration: 0.5)) {
                animationProgress = 1.0
            }
            
            // Start fading out slightly delayed
            withAnimation(.easeIn(duration: 0.4).delay(0.1)) {
                opacity = 0
            }
        }
    }
    
    // Computed properties for color transition
    private var transitionColor: Color {
        Color.interpolate(
            from: PreloadingState.preloading.color,
            to: PreloadingState.preloaded.color,
            fraction: animationProgress
        )
    }
    
    private var transitionSecondaryColor: Color {
        Color.interpolate(
            from: PreloadingState.preloading.secondaryColor,
            to: PreloadingState.preloaded.secondaryColor,
            fraction: animationProgress
        )
    }
}

// Dedicated animated view that handles its own animation lifecycle using MeshGradient
struct AnimatedBorderView: View {
    let width: CGFloat
    let height: CGFloat
    let color: Color
    let secondaryColor: Color
    let isTransitioning: Bool
    
    // Animation controls
    @State private var pulsing = false
    @State private var meshPhase: Double = 0.0
    @State private var pointOffset: Double = 0.0
    
    // Define base colors for the mesh gradient
    private let baseColors: [Color] = [
        Color(hue: 0.0, saturation: 0.7, brightness: 0.9),   // Red
        Color(hue: 0.17, saturation: 0.7, brightness: 0.9),  // Orange
        Color(hue: 0.33, saturation: 0.7, brightness: 0.9),  // Yellow-Green
        Color(hue: 0.45, saturation: 0.7, brightness: 0.9),  // Green
        Color(hue: 0.57, saturation: 0.7, brightness: 0.9),  // Cyan
        Color(hue: 0.7, saturation: 0.7, brightness: 0.9),   // Blue
        Color(hue: 0.83, saturation: 0.7, brightness: 0.9),  // Purple
        Color(hue: 0.95, saturation: 0.7, brightness: 0.9)   // Magenta
    ]
    
    // Generate animated colors for the 3x3 mesh control points
    private func meshColor(at index: Int) -> Color {
        let colorIndex = (index + Int(meshPhase * 8)) % baseColors.count
        return baseColors[colorIndex]
    }
    
    // Generate secondary (darker) colors for the inner glow mesh
    private func secondaryMeshColor(at index: Int) -> Color {
        return meshColor(at: index).opacity(0.85)
    }
    
    // Animated mesh points that subtly move the control points
    private var animatedMeshPoints: [SIMD2<Float>] {
        let baseOffset = Float(pointOffset) * 0.05 // Small movement range
        return [
            [0.0 + sin(Float.pi * 2 * baseOffset) * 0.02, 0.0 + cos(Float.pi * 2 * baseOffset) * 0.02],
            [0.5 + cos(Float.pi * 2 * baseOffset * 1.5) * 0.015, 0.0 + sin(Float.pi * 2 * baseOffset * 1.5) * 0.015],
            [1.0 + sin(Float.pi * 2 * baseOffset * 0.8) * 0.02, 0.0 + cos(Float.pi * 2 * baseOffset * 0.8) * 0.02],
            
            [0.0 + cos(Float.pi * 2 * baseOffset * 1.2) * 0.015, 0.5 + sin(Float.pi * 2 * baseOffset * 1.2) * 0.015],
            [0.5 + sin(Float.pi * 2 * baseOffset * 0.9) * 0.01, 0.5 + cos(Float.pi * 2 * baseOffset * 0.9) * 0.01],
            [1.0 + cos(Float.pi * 2 * baseOffset * 1.3) * 0.015, 0.5 + sin(Float.pi * 2 * baseOffset * 1.3) * 0.015],
            
            [0.0 + sin(Float.pi * 2 * baseOffset * 0.7) * 0.02, 1.0 + cos(Float.pi * 2 * baseOffset * 0.7) * 0.02],
            [0.5 + cos(Float.pi * 2 * baseOffset * 1.1) * 0.015, 1.0 + sin(Float.pi * 2 * baseOffset * 1.1) * 0.015],
            [1.0 + sin(Float.pi * 2 * baseOffset * 1.4) * 0.02, 1.0 + cos(Float.pi * 2 * baseOffset * 1.4) * 0.02]
        ]
    }
    
    var body: some View {
        ZStack {
            // Primary glow - stroke the EdgeBorder shape with MeshGradient
            EdgeBorder(width: pulsing ? 4.5 : 2.0)
                .stroke(
                    MeshGradient(
                        width: 3,
                        height: 3,
                        points: animatedMeshPoints,
                        colors: [
                            meshColor(at: 0), meshColor(at: 1), meshColor(at: 2),
                            meshColor(at: 3), meshColor(at: 4), meshColor(at: 5),
                            meshColor(at: 6), meshColor(at: 7), meshColor(at: 8)
                        ]
                    ),
                    lineWidth: pulsing ? 4.5 : 2.0
                )
                .blur(radius: pulsing ? 6.0 : 3.0)
                .opacity(pulsing ? 0.9 : 0.6)
            
            // Secondary inner glow - stroke with a secondary mesh gradient for depth
            EdgeBorder(width: pulsing ? 2.5 : 1.5)
                .stroke(
                    MeshGradient(
                        width: 3,
                        height: 3,
                        points: animatedMeshPoints,
                        colors: [
                            secondaryMeshColor(at: 0), secondaryMeshColor(at: 1), secondaryMeshColor(at: 2),
                            secondaryMeshColor(at: 3), secondaryMeshColor(at: 4), secondaryMeshColor(at: 5),
                            secondaryMeshColor(at: 6), secondaryMeshColor(at: 7), secondaryMeshColor(at: 8)
                        ]
                    ),
                    lineWidth: pulsing ? 2.5 : 1.5
                )
                .blur(radius: pulsing ? 4.0 : 2.0)
                .opacity(pulsing ? 0.8 : 0.5)
        }
        .onAppear {
            // Start both pulse and mesh animations
            startAnimations()
        }
        .onChange(of: isTransitioning) { transitioning in
            // If we just finished transitioning, restart the animations
            if !transitioning {
                startAnimations()
            }
        }
    }
    
    private func startAnimations() {
        // Reset animation state
        pulsing = false
        meshPhase = 0.0
        pointOffset = 0.0
        
        // Start the pulse animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            // Use withAnimation to ensure the repeating animation works properly
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
        
        // Start the mesh gradient color animation
        withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
            meshPhase = 1.0
        }
        
        // Start the mesh point animation (slower, subtler movement)
        withAnimation(.linear(duration: 12.0).repeatForever(autoreverses: false)) {
            pointOffset = 1.0
        }
    }
}

// Extension to interpolate between colors
extension Color {
    static func interpolate(from: Color, to: Color, fraction: CGFloat) -> Color {
        // Simple linear interpolation between colors
        let clampedFraction = min(1.0, max(0.0, fraction))
        
        // Convert Colors to UIColors for easier component access
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        // Use UIColor conversion for simplicity
        UIColor(from).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        UIColor(to).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        // Interpolate each component
        let r = r1 + (r2 - r1) * clampedFraction
        let g = g1 + (g2 - g1) * clampedFraction
        let b = b1 + (b2 - b1) * clampedFraction
        let a = a1 + (a2 - a1) * clampedFraction
        
        return Color(UIColor(red: r, green: g, blue: b, alpha: a))
    }
    
    // Generate a rainbow color at a specific position (0-1)
    static func rainbow(at position: Double) -> Color {
        let clampedPosition = position.truncatingRemainder(dividingBy: 1.0)
        return Color(hue: clampedPosition, saturation: 0.8, brightness: 0.9)
    }
}

// Custom shape to draw only the edge border outline
struct EdgeBorder: Shape {
    let width: CGFloat
    
    // Add animation support
    var animatableData: CGFloat {
        get { width }
        set { }  // Read-only, just for animation
    }
    
    func path(in rect: CGRect) -> Path {
        // Get the device corner radius from our service
        let cornerRadius = ScreenCornerService.shared.cornerRadius
        
        // Create a simple outline path for stroking (not a filled border path)
        return DeviceScreenShape.path(in: rect, cornerRadius: cornerRadius)
    }
}

// Alternative shape for mask-based borders (used in TransitionOverlay)
struct EdgeBorderMask: Shape {
    let width: CGFloat
    
    // Add animation support
    var animatableData: CGFloat {
        get { width }
        set { }  // Read-only, just for animation
    }
    
    func path(in rect: CGRect) -> Path {
        // Get the device corner radius from our service
        let cornerRadius = ScreenCornerService.shared.cornerRadius
        
        // Use the border path for masking operations
        return DeviceScreenShape.borderPath(in: rect, cornerRadius: cornerRadius, lineWidth: width)
    }
}

// Preview with transition animation
struct RetroEdgePreloadIndicator_Previews: PreviewProvider {
    static var previews: some View {
        PreviewAnimator()
    }
    
    // Preview helper that cycles through states
    struct PreviewAnimator: View {
        @State private var state: PreloadingState = .preloading
        
        var body: some View {
            ZStack {
                Color.black
                Text("Video Content")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                RetroEdgePreloadIndicator(state: state)
                
                VStack {
                    Spacer()
                    
                    Button("Trigger Transition") {
                        state = state == .preloading ? .preloaded : .preloading
                    }
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.bottom, 50)
                }
            }
        }
    }
}