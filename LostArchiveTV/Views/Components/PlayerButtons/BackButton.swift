import SwiftUI

struct BackButton: View {
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.title2)
                .foregroundColor(.white)
                .padding(12)
                .background(Circle().fill(Color.black.opacity(0.5)))
        }
        .padding(.top, 50)
        .padding(.leading, 16)
    }
}