import SwiftUI

struct FavoriteButton: View {
    var isFavorite: Bool
    var action: () -> Void
    var disabled: Bool
    
    var body: some View {
        PlayerButton.stateful(
            activeIcon: "heart.fill",
            inactiveIcon: "heart",
            isActive: isFavorite,
            activeColor: .red,
            inactiveColor: .white,
            action: action,
            disabled: disabled,
            hapticFeedback: .medium
        )
    }
}