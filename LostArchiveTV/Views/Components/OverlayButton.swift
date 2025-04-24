import SwiftUI

struct OverlayButton<Content: View>: View {
    var action: () -> Void
    var disabled: Bool
    @ViewBuilder var content: () -> Content
    
    init(action: @escaping () -> Void, disabled: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.action = action
        self.disabled = disabled
        self.content = content
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                content()
            }
        }
        .disabled(disabled)
    }
}