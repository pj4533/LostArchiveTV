import SwiftUI

struct VideoCard: View {
    let video: ArchiveVideo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail image
            AsyncImage(url: video.thumbnailUrl) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .foregroundColor(.gray.opacity(0.3))
                        .aspectRatio(16/9, contentMode: .fill)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Rectangle()
                        .foregroundColor(.gray.opacity(0.3))
                        .aspectRatio(16/9, contentMode: .fill)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.white)
                        )
                @unknown default:
                    Rectangle()
                        .foregroundColor(.gray.opacity(0.3))
                        .aspectRatio(16/9, contentMode: .fill)
                }
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Video info
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.headline)
                    .lineLimit(2)
                
                if let creator = video.creator {
                    Text(creator)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                if let date = video.date {
                    Text(date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 6)
        }
        .padding(.bottom, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}