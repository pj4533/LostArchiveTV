import SwiftUI

struct IdentifierSavedNotification: View {
    let title: String
    let presetName: String?
    @Binding var isVisible: Bool
    var isDuplicate: Bool = false
    
    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: isDuplicate ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(isDuplicate ? .yellow : .green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(isDuplicate ? "Already Added" : "Video Added")
                        .font(.headline)
                    
                    if let presetName = presetName {
                        if isDuplicate {
                            Text("\"\(title)\" is already in \"\(presetName)\"")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        } else {
                            Text("\"\(title)\" saved to \"\(presetName)\"")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    } else {
                        Text("\"\(title)\" \(isDuplicate ? "is already in your identifier list" : "saved to your identifier list")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
            )
            .padding(.horizontal)
        }
        .transition(.move(edge: .top).combined(with: .opacity))
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