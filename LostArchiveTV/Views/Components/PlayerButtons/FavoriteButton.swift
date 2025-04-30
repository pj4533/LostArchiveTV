import SwiftUI

struct FavoriteButton: View {
    var isFavorite: Bool
    var action: () -> Void
    var disabled: Bool
    
    var body: some View {
        OverlayButton(
            action: {
                action()
                // Add haptic feedback
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            },
            disabled: disabled
        ) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22)
                .foregroundColor(isFavorite ? .red : .white)
                .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
        }
    }
}