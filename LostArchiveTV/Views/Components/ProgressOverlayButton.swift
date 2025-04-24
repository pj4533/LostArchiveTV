import SwiftUI

// Progress button variant that shows download progress
struct ProgressOverlayButton: View {
    var action: () -> Void
    var progress: Float
    var isInProgress: Bool
    var normalIcon: String
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                if isInProgress {
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                } else {
                    Image(systemName: normalIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22, height: 22)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                }
            }
        }
        .disabled(isInProgress)
    }
}