import SwiftUI

struct OverlayButton<Content: View>: View {
    var action: () -> Void
    var disabled: Bool
    @State private var isPressed = false
    @ViewBuilder var content: () -> Content
    
    init(action: @escaping () -> Void, disabled: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.action = action
        self.disabled = disabled
        self.content = content
    }
    
    var body: some View {
        Button {
            isPressed = true
            
            // Execute the action
            action()
            
            // Reset animation state after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isPressed = false
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                content()
                    .scaleEffect(isPressed ? 0.8 : 0.95)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            }
        }
        .disabled(disabled)
    }
}