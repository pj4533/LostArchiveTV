import SwiftUI

/// A unified button component that supports all player button styles and configurations
struct PlayerButton: View {
    // MARK: - Properties
    
    let icon: ButtonIcon
    let size: ButtonSize
    let style: ButtonStyle
    let color: ButtonColor
    let action: () -> Void
    let disabled: Bool
    let showShadow: Bool
    let hapticFeedback: UIImpactFeedbackGenerator.FeedbackStyle?
    let customPadding: EdgeInsets?
    let touchTargetSize: CGFloat
    
    // MARK: - Initialization
    
    init(
        icon: ButtonIcon,
        size: ButtonSize = .medium,
        style: ButtonStyle = .overlay,
        color: ButtonColor = .white,
        action: @escaping () -> Void,
        disabled: Bool = false,
        showShadow: Bool = true,
        hapticFeedback: UIImpactFeedbackGenerator.FeedbackStyle? = nil,
        customPadding: EdgeInsets? = nil,
        touchTargetSize: CGFloat = 44
    ) {
        self.icon = icon
        self.size = size
        self.style = style
        self.color = color
        self.action = action
        self.disabled = disabled
        self.showShadow = showShadow
        self.hapticFeedback = hapticFeedback
        self.customPadding = customPadding
        self.touchTargetSize = touchTargetSize
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if style.usesOverlay {
                overlayButton
            } else {
                standardButton
            }
        }
        .if(customPadding != nil) { view in
            view.padding(customPadding!)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            // Standard overlay buttons
            PlayerButton.system("heart", action: {})
            PlayerButton.system("gearshape.fill", action: {})
            PlayerButton.system("backward.end", size: .small, action: {})
        }
        
        HStack(spacing: 20) {
            // Stateful button (favorite)
            PlayerButton.stateful(
                activeIcon: "heart.fill",
                inactiveIcon: "heart",
                isActive: true,
                action: {}
            )
            
            PlayerButton.stateful(
                activeIcon: "heart.fill",
                inactiveIcon: "heart",
                isActive: false,
                action: {}
            )
        }
        
        HStack(spacing: 20) {
            // Minimal button
            PlayerButton.minimal("plus", action: {})
            PlayerButton.minimal("plus", action: {}, disabled: true)
        }
        
        HStack(spacing: 20) {
            // Back button
            PlayerButton.back(action: {})
        }
    }
    .padding()
    .background(Color.blue) // To see buttons against background
}