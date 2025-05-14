import SwiftUI

struct SavedIdentifierOverlay: View {
    var title: String
    var presetName: String?
    @Binding var isVisible: Bool
    
    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Saved to Library")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if let presetName = presetName {
                        Text("Added to preset: \(presetName)")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        isVisible = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white.opacity(0.7))
                        .padding(8)
                }
            }
            .padding(16)
            .background(Color.black.opacity(0.8))
            .cornerRadius(12)
            .shadow(radius: 5)
        }
        .padding(.horizontal)
        .onAppear {
            // Auto-dismiss after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    isVisible = false
                }
            }
        }
    }
}

#Preview {
    SavedIdentifierOverlay(
        title: "Example Video Title",
        presetName: "Favorites",
        isVisible: .constant(true)
    )
    .background(Color.gray)
}