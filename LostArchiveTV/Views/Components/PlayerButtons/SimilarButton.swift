import SwiftUI

struct SimilarButton: View {
    var action: () -> Void
    var disabled: Bool
    
    var body: some View {
        OverlayButton(
            action: action,
            disabled: disabled
        ) {
            Image(systemName: "sparkles.rectangle.stack")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
        }
    }
}