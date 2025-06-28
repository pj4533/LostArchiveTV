import SwiftUI

struct SaveIdentifierButton: View {
    var action: () -> Void
    var disabled: Bool

    var body: some View {
        PlayerButton(
            icon: .system("plus"),
            size: .font(22),
            style: .minimal,
            color: .white,
            action: action,
            disabled: disabled,
            showShadow: false,
            touchTargetSize: 40
        )
    }
}