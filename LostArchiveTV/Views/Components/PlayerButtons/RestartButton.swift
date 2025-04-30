import SwiftUI

struct RestartButton: View {
    var action: () -> Void
    var disabled: Bool
    
    var body: some View {
        OverlayButton(
            action: action,
            disabled: disabled
        ) {
            Image(systemName: "backward.end")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
        }
    }
}