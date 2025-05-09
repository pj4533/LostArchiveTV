import SwiftUI

struct SaveIdentifierButton: View {
    var action: () -> Void
    var disabled: Bool

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22))
                .foregroundColor(disabled ? .gray : .white)
        }
        .disabled(disabled)
        .frame(width: 40, height: 40)
    }
}