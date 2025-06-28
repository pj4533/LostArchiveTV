import SwiftUI

/// A unified button component that supports all player button styles and configurations
struct PlayerButton: View {
    // MARK: - Configuration Types
    
    /// Icon configuration for the button
    enum ButtonIcon {
        case system(String)
        case asset(String)
        case stateful(active: String, inactive: String, isActive: Bool)
        
        var iconName: String {
            switch self {
            case .system(let name):
                return name
            case .asset(let name):
                return name
            case .stateful(let active, let inactive, let isActive):
                return isActive ? active : inactive
            }
        }
        
        var isSystemIcon: Bool {
            switch self {
            case .system, .stateful:
                return true
            case .asset:
                return false
            }
        }
    }
    
    /// Size configuration for the button
    enum ButtonSize {
        case small      // 16x16
        case medium     // 22x22 (default)
        case large      // 32x32
        case font(CGFloat) // Font-based sizing
        
        var dimensions: CGSize? {
            switch self {
            case .small:
                return CGSize(width: 16, height: 16)
            case .medium:
                return CGSize(width: 22, height: 22)
            case .large:
                return CGSize(width: 32, height: 32)
            case .font:
                return nil
            }
        }
        
        var fontSize: CGFloat? {
            switch self {
            case .font(let size):
                return size
            default:
                return nil
            }
        }
    }
    
    /// Style configuration for the button
    enum ButtonStyle {
        case overlay        // Uses OverlayButton with circle background
        case minimal        // No background, just icon
        case custom(Color, CGFloat) // Custom background color and opacity
        
        var usesOverlay: Bool {
            switch self {
            case .overlay:
                return true
            case .minimal, .custom:
                return false
            }
        }
    }
    
    /// Color configuration for the button
    enum ButtonColor {
        case white
        case red
        case gray
        case stateful(active: Color, inactive: Color, isActive: Bool)
        
        var color: Color {
            switch self {
            case .white:
                return .white
            case .red:
                return .red
            case .gray:
                return .gray
            case .stateful(let active, let inactive, let isActive):
                return isActive ? active : inactive
            }
        }
    }
    
    // MARK: - Properties
    
    private let icon: ButtonIcon
    private let size: ButtonSize
    private let style: ButtonStyle
    private let color: ButtonColor
    private let action: () -> Void
    private let disabled: Bool
    private let showShadow: Bool
    private let hapticFeedback: UIImpactFeedbackGenerator.FeedbackStyle?
    private let customPadding: EdgeInsets?
    private let touchTargetSize: CGFloat
    
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
    
    // MARK: - Button Implementations
    
    private var overlayButton: some View {
        OverlayButton(
            action: handleAction,
            disabled: disabled
        ) {
            iconView
                .if(showShadow) { view in
                    view.shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                }
        }
    }
    
    private var standardButton: some View {
        Button(action: handleAction) {
            Group {
                switch style {
                case .minimal:
                    iconView
                        .frame(width: touchTargetSize, height: touchTargetSize)
                    
                case .custom(let backgroundColor, let opacity):
                    iconView
                        .padding(12)
                        .background(Circle().fill(backgroundColor.opacity(opacity)))
                        .if(showShadow) { view in
                            view.shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                        }
                    
                case .overlay:
                    // This case is handled by overlayButton
                    EmptyView()
                }
            }
        }
        .disabled(disabled)
    }
    
    private var iconView: some View {
        Group {
            if icon.isSystemIcon {
                if let fontSize = size.fontSize {
                    Image(systemName: icon.iconName)
                        .font(.system(size: fontSize))
                        .foregroundColor(effectiveColor)
                } else if let dimensions = size.dimensions {
                    Image(systemName: icon.iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: dimensions.width, height: dimensions.height)
                        .foregroundColor(effectiveColor)
                } else {
                    Image(systemName: icon.iconName)
                        .foregroundColor(effectiveColor)
                }
            } else {
                // Asset image
                if let dimensions = size.dimensions {
                    Image(icon.iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: dimensions.width, height: dimensions.height)
                        .clipShape(Circle())
                        .if(showShadow) { view in
                            view.shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                        }
                } else {
                    Image(icon.iconName)
                        .clipShape(Circle())
                        .if(showShadow) { view in
                            view.shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                        }
                }
            }
        }
    }
    
    private var effectiveColor: Color {
        if disabled {
            return .gray
        }
        return color.color
    }
    
    private func handleAction() {
        // Add haptic feedback if specified
        if let hapticStyle = hapticFeedback {
            UIImpactFeedbackGenerator(style: hapticStyle).impactOccurred()
        }
        
        action()
    }
}

// MARK: - Convenience Initializers

extension PlayerButton {
    /// Creates a standard overlay button with system icon
    static func system(
        _ iconName: String,
        size: ButtonSize = .medium,
        color: ButtonColor = .white,
        action: @escaping () -> Void,
        disabled: Bool = false
    ) -> PlayerButton {
        PlayerButton(
            icon: .system(iconName),
            size: size,
            style: .overlay,
            color: color,
            action: action,
            disabled: disabled
        )
    }
    
    /// Creates a stateful button (like favorite button)
    static func stateful(
        activeIcon: String,
        inactiveIcon: String,
        isActive: Bool,
        activeColor: Color = .red,
        inactiveColor: Color = .white,
        size: ButtonSize = .medium,
        action: @escaping () -> Void,
        disabled: Bool = false,
        hapticFeedback: UIImpactFeedbackGenerator.FeedbackStyle? = .medium
    ) -> PlayerButton {
        PlayerButton(
            icon: .stateful(active: activeIcon, inactive: inactiveIcon, isActive: isActive),
            size: size,
            style: .overlay,
            color: .stateful(active: activeColor, inactive: inactiveColor, isActive: isActive),
            action: action,
            disabled: disabled,
            hapticFeedback: hapticFeedback
        )
    }
    
    /// Creates a minimal button (no background)
    static func minimal(
        _ iconName: String,
        fontSize: CGFloat = 22,
        action: @escaping () -> Void,
        disabled: Bool = false
    ) -> PlayerButton {
        PlayerButton(
            icon: .system(iconName),
            size: .font(fontSize),
            style: .minimal,
            color: disabled ? .gray : .white,
            action: action,
            disabled: disabled,
            showShadow: false
        )
    }
    
    /// Creates a back button with custom styling and positioning
    static func back(
        action: @escaping () -> Void
    ) -> PlayerButton {
        PlayerButton(
            icon: .system("chevron.left"),
            size: .font(20), // title2 font equivalent
            style: .custom(.black, 0.5),
            color: .white,
            action: action,
            showShadow: false,
            customPadding: EdgeInsets(top: 50, leading: 16, bottom: 0, trailing: 0)
        )
    }
    
    /// Creates an archive button with custom asset
    static func archive(
        identifier: String?,
        openURL: OpenURLAction
    ) -> PlayerButton {
        PlayerButton(
            icon: .asset("internetarchive"),
            size: .large,
            style: .custom(.black, 0.1),
            action: {
                if let identifier = identifier,
                   let url = URL(string: "https://archive.org/details/\(identifier)") {
                    openURL(url)
                }
            },
            touchTargetSize: 44
        )
    }
}

// MARK: - View Extension for Conditional Modifiers

extension View {
    /// Applies a view modifier conditionally
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
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