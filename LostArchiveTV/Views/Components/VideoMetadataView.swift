import SwiftUI
import AVFoundation
import OSLog

struct VideoMetadataView: View {
    let title: String?
    let collection: String?
    let description: String?
    let identifier: String?
    let filename: String?
    var currentTime: Double? = nil
    var duration: Double? = nil
    var totalFiles: Int? = nil
    
    private func formatTime(_ seconds: Double) -> String {
        // Check for invalid values (NaN or infinity)
        guard !seconds.isNaN && !seconds.isInfinite else {
            return "0:00"
        }
        
        // Convert to positive value and round to nearest second
        let totalSeconds = Int(max(0, seconds.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
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
            
            if let filename = filename {
                if let totalFiles = totalFiles, totalFiles > 1 {
                    Text("\(totalFiles) Files: \(filename)")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                        // Removed noisy logging
                        .id("\(totalFiles)_\(filename)") // Force refresh when either totalFiles or filename changes
                } else {
                    Text("File: \(filename)")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                        // Removed noisy logging
                        .id("\(totalFiles ?? 0)_\(filename)") // Force refresh when either totalFiles or filename changes
                }
            }
            
            if let currentTime = currentTime, let duration = duration {
                Text("Time: \(formatTime(currentTime)) / \(formatTime(duration))")
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