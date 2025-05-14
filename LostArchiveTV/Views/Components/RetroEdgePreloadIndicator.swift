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
            EdgeBorder(width: 25)
                .stroke(transitionColor, lineWidth: 25)
                .blur(radius: 40)
                .opacity(opacity)
                .scaleEffect(scale)
            
            // Inner explosion
            EdgeBorder(width: 15)
                .stroke(transitionSecondaryColor, lineWidth: 15)
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

// Dedicated animated view that handles its own animation lifecycle - mostly unchanged from original
struct AnimatedBorderView: View {
    let width: CGFloat
    let height: CGFloat
    let color: Color
    let secondaryColor: Color
    let isTransitioning: Bool
    
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
            startPulseAnimation()
        }
        .onChange(of: isTransitioning) { transitioning in
            // If we just finished transitioning, restart the pulse
            if !transitioning {
                startPulseAnimation()
            }
        }
    }
    
    private func startPulseAnimation() {
        // Reset pulsing to restart animation
        pulsing = false
        
        // Then start animation after a tiny delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            // Use withAnimation to ensure the repeating animation works properly
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                pulsing = true
            }
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
        // Get the device corner radius from our service
        let cornerRadius = ScreenCornerService.shared.cornerRadius
        
        // Use our helper to create a path with the correct device corner radius
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