import SwiftUI

// Button specialized for the internet archive icon
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