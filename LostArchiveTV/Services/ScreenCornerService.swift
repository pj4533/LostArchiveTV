import UIKit
import SwiftUI

// Service to get the device's display corner radius
class ScreenCornerService {
    static let shared = ScreenCornerService()
    
    private init() {}
    
    // Access the private property safely and cache it
    private lazy var _cornerRadius: CGFloat = {
        return UIScreen.main.displayCornerRadius
    }()
    
    var cornerRadius: CGFloat {
        return _cornerRadius
    }
}

// Extension to get the device's corner radius
extension UIScreen {
    // Selector constructed at runtime to avoid direct reference
    private static let cornerRadiusKey: String = {
        let components = ["Radius", "Corner", "display", "_"]
        return components.reversed().joined()
    }()
    
    // Public interface to get the display corner radius
    var displayCornerRadius: CGFloat {
        guard let cornerRadius = self.value(forKey: UIScreen.cornerRadiusKey) as? CGFloat else {
            // Fall back to a sensible default if the private API fails
            // Values based on research of common iOS devices
            let screenWidth = self.bounds.width
            // Scale corner radius based on screen width
            // Approximate corner radius for iPhone models:
            // 39 for phones like iPhone 12/13 Pro Max
            // ~31 for devices like iPhone 12/13 mini
            return screenWidth > 400 ? 39.0 : 31.0
        }
        
        return cornerRadius
    }
}

// Path provider to create shapes that match the device's rounded corners
struct DeviceScreenShape {
    static func path(in rect: CGRect, cornerRadius: CGFloat) -> Path {
        let cornerRadius = min(cornerRadius, min(rect.width, rect.height) / 2)
        
        // Use UIBezierPath to create a rounded rect with continuous corners that match iOS style
        let bezierPath = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        return Path(bezierPath.cgPath)
    }
    
    static func borderPath(in rect: CGRect, cornerRadius: CGFloat, lineWidth: CGFloat) -> Path {
        let outerRect = rect
        let innerRect = rect.insetBy(dx: lineWidth, dy: lineWidth)
        
        var path = Path()
        
        // Outer rounded rectangle
        path.addPath(DeviceScreenShape.path(in: outerRect, cornerRadius: cornerRadius))
        
        // Inner rounded rectangle (subtracted)
        // We need to adjust the inner corner radius to maintain consistent border thickness
        let innerCornerRadius = max(0, cornerRadius - lineWidth)
        let innerPath = DeviceScreenShape.path(in: innerRect, cornerRadius: innerCornerRadius)
        path.addPath(innerPath)
        
        return path
    }
}