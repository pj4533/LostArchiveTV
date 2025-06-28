import SwiftUI

struct TrimButton: View {
    var action: () -> Void
    var disabled: Bool
    
    var body: some View {
        PlayerButton.system(
            "selection.pin.in.out",
            action: action,
            disabled: disabled
        )
    }
}