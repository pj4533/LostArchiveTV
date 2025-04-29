import SwiftUI

struct FeedItemCell<Item: FeedItem>: View {
    let item: Item
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Thumbnail
            AsyncImage(url: item.thumbnailURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                ZStack {
                    Color.gray.opacity(0.3)
                    Image(systemName: "film")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                }
            }
            .frame(width: 80, height: 80)
            .cornerRadius(8)
            
            // Metadata
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                if let description = item.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Additional metadata
                ForEach(item.metadata.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    HStack {
                        Text(key + ":")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(value)
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}