import SwiftUI

struct SimilarButton: View {
    var action: () -> Void
    var disabled: Bool
    
    var body: some View {
        PlayerButton.system(
            "sparkles.rectangle.stack",
            action: action,
            disabled: disabled
        )
    }
}