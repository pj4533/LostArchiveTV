//
//  PlayerButton+Types.swift
//  LostArchiveTV
//
//  Created by Claude on 2025-06-30.
//

import SwiftUI

extension PlayerButton {
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
}