import SwiftUI
import AVFoundation

struct VideoMetadataView: View {
    let title: String?
    let collection: String?
    let description: String?
    let identifier: String?
    var currentTime: Double? = nil
    var duration: Double? = nil
    
    private func formatTime(_ seconds: Double) -> String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: seconds)) ?? "\(seconds)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title ?? identifier ?? "Unknown Title")
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)
            
            if let collection = collection {
                Text("Collection: \(collection)")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }
            
            if let currentTime = currentTime, let duration = duration {
                Text("Clip: \(formatTime(currentTime))s of \(formatTime(duration))s")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }
            
            Text(description ?? "Internet Archive random video clip")
                .font(.subheadline)
                .foregroundColor(.gray)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .padding(.trailing, 60) // Make room for the buttons on the right
    }
}