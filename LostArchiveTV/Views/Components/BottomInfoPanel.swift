import SwiftUI

struct BottomInfoPanel: View {
    let title: String?
    let collection: String?
    let description: String?
    let identifier: String?
    let filename: String?
    let currentTime: Double?
    let duration: Double
    
    init(title: String?, collection: String?, description: String?, identifier: String?, filename: String? = nil, currentTime: Double?, duration: Double) {
        self.title = title
        self.collection = collection
        self.description = description
        self.identifier = identifier
        self.filename = filename
        self.currentTime = currentTime
        // Ensure duration is valid (not NaN or infinity)
        if duration.isNaN || duration.isInfinite {
            self.duration = 0
        } else {
            self.duration = duration
        }
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            // Bottom overlay with title and description
            VStack(alignment: .leading, spacing: 8) {
                // Video metadata (title, collection, description, filename)
                VideoMetadataView(
                    title: title,
                    collection: collection,
                    description: description,
                    identifier: identifier,
                    filename: filename,
                    currentTime: currentTime,
                    duration: duration
                )
                .id(duration) // Force view refresh when duration updates
                
                // Swipe hint
                Text("Swipe up for next video")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}