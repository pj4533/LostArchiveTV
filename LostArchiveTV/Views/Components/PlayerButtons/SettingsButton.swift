import SwiftUI

struct SettingsButton: View {
    var action: () -> Void
    var disabled: Bool
    
    var body: some View {
        PlayerButton.system(
            "gearshape.fill",
            action: action,
            disabled: disabled
        )
    }
}