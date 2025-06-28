import SwiftUI

struct RestartButton: View {
    var action: () -> Void
    var disabled: Bool
    
    var body: some View {
        PlayerButton.system(
            "backward.end",
            size: .small,
            action: action,
            disabled: disabled
        )
    }
}