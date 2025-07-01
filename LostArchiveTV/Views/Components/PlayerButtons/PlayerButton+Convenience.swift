//
//  PlayerButton+Convenience.swift
//  LostArchiveTV
//
//  Created by Claude on 2025-06-30.
//

import SwiftUI

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