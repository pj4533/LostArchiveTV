import SwiftUI

/// A view modifier that adds a shimmer/sparkle effect to text
struct ShimmerTextEffect: ViewModifier {
    // Whether animation should be shown
    let animationActive: Bool
    
    // Animation sequence state (using separate namespace from view state)
    private struct AnimationState {
        var phase: CGFloat = 0
        var scale: CGFloat = 1.0
        var isAnimating: Bool = false
    }
    
    // Use @State with initial value to ensure consistent starting point
    @State private var animation = AnimationState()
    
    // Enhanced shimmer colors with higher intensity
    private let shimmerColors: [Color] = [
        .white.opacity(0.8),    // Base color - brighter
        .blue,                  // Accent blue - full opacity
        .cyan,                  // Light blue - full opacity
        .white,                 // Bright highlight
        .yellow,                // Adding yellow for intensity
        .green,                 // Accent green - full opacity
        .white.opacity(0.8)     // Back to base
    ]
    
    func body(content: Content) -> some View {
        content
            // Apply overlay effect
            .overlay(
                GeometryReader { geometry in
                    if animationActive {
                        ZStack {
                            // Gradient overlay effect
                            LinearGradient(
                                gradient: Gradient(colors: shimmerColors),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .scaleEffect(1.5) 
                            .offset(x: -geometry.size.width + (2 * geometry.size.width * animation.phase))
                            .blendMode(.overlay)
                            .mask(content.foregroundColor(.white))
                            
                            // Sparkle effects - separate from gradient
                            ForEach(0..<12, id: \.self) { i in
                                sparkle(at: i, in: geometry)
                            }
                            .mask(content.foregroundColor(.white))
                        }
                    }
                }
            )
            // Apply single scaling to whole content
            .scaleEffect(animation.scale)
            .onChange(of: animationActive) { oldValue, isActive in
                // Only trigger when animation becomes active
                guard isActive else { return }
                
                // Start fresh with each activation to ensure consistency
                resetAnimationState()
                
                // Begin animation sequence
                startAnimation()
            }
    }
    
    // Reset to known initial state
    private func resetAnimationState() {
        // No animation for reset - happens immediately
        animation.phase = 0
        animation.scale = 1.0
        animation.isAnimating = false
    }
    
    // Run complete animation sequence
    private func startAnimation() {
        guard !animation.isAnimating else { return }
        
        animation.isAnimating = true
        
        // Phase 1: Scale up with shimmer
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            animation.scale = 1.25
            animation.phase = 1.0
        }
        
        // Phase 2: Scale back to normal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.3)) {
                animation.scale = 1.0
                
                // Mark as complete when animation finishes
                animation.isAnimating = false
            }
        }
    }
    
    // Create a sparkle at a specific position
    private func sparkle(at index: Int, in geometry: GeometryProxy) -> some View {
        let position = sparklePosition(for: index, in: geometry)
        let delay = Double(index) * 0.04 // Staggered appearances
        
        // Alternate colors for more visual impact
        let colors: [Color] = [.white, .yellow, .cyan]
        let sparkleColor = colors[index % colors.count]
        
        return Circle()
            .fill(sparkleColor)
            .frame(width: 7, height: 7)
            .position(position)
            .blur(radius: 1.5)
            .opacity(sparkleOpacity(for: index))
            .animation(
                Animation
                    .easeInOut(duration: 0.4)
                    .delay(delay),
                value: animation.phase
            )
    }
    
    // Opacity calculation for each sparkle
    private func sparkleOpacity(for index: Int) -> Double {
        // No animation if not active
        guard animation.isAnimating else { return 0 }
        
        // Show sparkles during middle of animation phase
        let progress = animation.phase
        let showRange = (0.25...0.85) // Visible during this phase range
        
        if showRange.contains(progress) {
            // Peak in the middle of the range
            let normalizedPos = (progress - showRange.lowerBound) / (showRange.upperBound - showRange.lowerBound)
            
            // Stagger sparkle opacities based on index
            let peakOffset = Double(index % 8) * 0.1
            let adjustedPos = normalizedPos - peakOffset
            
            // Bell curve-like opacity
            return min(1.0, 1.0 - pow(adjustedPos * 2.0 - 1.0, 2) * 0.8)
        }
        
        return 0
    }
    
    // Position calculations for sparkles
    private func sparklePosition(for index: Int, in geometry: GeometryProxy) -> CGPoint {
        let width = geometry.size.width
        let height = geometry.size.height
        
        // More positions for many sparkles
        let xFactors = [0.15, 0.3, 0.45, 0.6, 0.75, 0.9, 0.2, 0.4, 0.6, 0.8, 0.1, 0.5]
        let yFactors = [0.2, 0.4, 0.6, 0.3, 0.5, 0.7, 0.8, 0.25, 0.75, 0.5, 0.9, 0.1]
        
        let idx = index % min(xFactors.count, yFactors.count)
        return CGPoint(x: width * xFactors[idx], y: height * yFactors[idx])
    }
}

// Extension for easy use
extension View {
    func shimmerEffect(active: Bool) -> some View {
        self.modifier(ShimmerTextEffect(animationActive: active))
    }
}

// Preview provider
struct ShimmerTextEffect_Previews: PreviewProvider {
    struct TestView: View {
        @State private var animating = false
        
        var body: some View {
            VStack {
                Text("Swipe up for next video")
                    .font(.title2)
                    .shimmerEffect(active: animating)
                    .padding()
                
                Button("Trigger Animation") {
                    animating = true
                    
                    // Reset after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        animating = false
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()
            .background(Color.black)
        }
    }
    
    static var previews: some View {
        TestView()
    }
}