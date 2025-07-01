//
//  PlayerButton+Views.swift
//  LostArchiveTV
//
//  Created by Claude on 2025-06-30.
//

import SwiftUI

extension PlayerButton {
    // MARK: - Button View Implementations
    
    var overlayButton: some View {
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
    
    var standardButton: some View {
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
    
    var iconView: some View {
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
    
    var effectiveColor: Color {
        if disabled {
            return .gray
        }
        return color.color
    }
    
    func handleAction() {
        // Add haptic feedback if specified
        if let hapticStyle = hapticFeedback {
            UIImpactFeedbackGenerator(style: hapticStyle).impactOccurred()
        }
        
        action()
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