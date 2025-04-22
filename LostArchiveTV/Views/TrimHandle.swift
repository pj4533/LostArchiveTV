import SwiftUI

/// A view representing a draggable handle for video trimming
struct TrimHandle: View {
    @Binding var isDragging: Bool
    var orientation: HandleOrientation
    
    enum HandleOrientation {
        case left
        case right
    }
    
    private let handleWidth: CGFloat = 8
    private let handleHeight: CGFloat = 50
    
    var body: some View {
        ZStack {
            // Invisible larger touch area
            Rectangle()
                .fill(Color.clear)
                .frame(width: 44, height: handleHeight + 40) // Wider touch area
            
            // Handle bar
            Rectangle()
                .fill(Color.white)
                .frame(width: handleWidth, height: 50)
            
            // Top handle
            Circle()
                .fill(Color.white)
                .frame(width: 20, height: 20)
                .overlay(
                    Image(systemName: orientation == .left ? "chevron.left" : "chevron.right")
                        .foregroundColor(.black)
                        .font(.system(size: 10, weight: .bold))
                )
                .offset(y: -20)
            
            // Bottom handle
            Circle()
                .fill(Color.white)
                .frame(width: 20, height: 20)
                .overlay(
                    Image(systemName: orientation == .left ? "chevron.left" : "chevron.right")
                        .foregroundColor(.black)
                        .font(.system(size: 10, weight: .bold))
                )
                .offset(y: 20)
        }
        .frame(width: 44, height: handleHeight + 40)
        .contentShape(Rectangle())
    }
}