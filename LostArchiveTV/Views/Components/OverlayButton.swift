import SwiftUI

struct OverlayButton<Content: View>: View {
    var action: () -> Void
    var disabled: Bool
    @ViewBuilder var content: () -> Content
    
    init(action: @escaping () -> Void, disabled: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.action = action
        self.disabled = disabled
        self.content = content
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                content()
            }
        }
        .disabled(disabled)
    }
}

// Progress button variant
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

// Thumbnail button specialized for the internet archive icon
struct ArchiveButton: View {
    var identifier: String?
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        Button(action: {
            if let identifier = identifier,
               let url = URL(string: "https://archive.org/details/\(identifier)") {
                openURL(url)
            }
        }) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image("internetarchive")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
            }
        }
    }
}