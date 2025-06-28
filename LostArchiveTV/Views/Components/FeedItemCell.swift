import SwiftUI

struct FeedItemCell<Item: FeedItem>: View {
    let item: Item
    
    var body: some View {
        // Use specialized view for SearchFeedItem, generic view for others
        if let searchFeedItem = item as? SearchFeedItem {
            searchFeedItemView(searchFeedItem)
        } else {
            genericFeedItemView
        }
    }
    
    // Specialized view for SearchFeedItem that observes the SearchViewModel
    private func searchFeedItemView(_ searchFeedItem: SearchFeedItem) -> some View {
        SearchFeedItemCellContent(item: searchFeedItem, searchViewModel: searchFeedItem.searchViewModel)
    }
    
    private var genericFeedItemView: some View {
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

// Specialized content view for SearchFeedItem that observes SearchViewModel
struct SearchFeedItemCellContent: View {
    let item: SearchFeedItem
    @ObservedObject var searchViewModel: SearchViewModel
    
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
                
                // Additional metadata - computed dynamically based on cache version
                ForEach(dynamicMetadata.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
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
    
    // Dynamic metadata that re-computes when searchViewModel changes
    private var dynamicMetadata: [String: String] {
        var result: [String: String] = [:]
        result["Score"] = String(format: "%.2f", item.searchResult.score)
        if let year = item.searchResult.year {
            result["Year"] = String(year)
        }
        if !item.searchResult.collections.isEmpty {
            result["Collection"] = item.searchResult.collections.first!
        }
        
        // This will re-compute when fileCountCacheVersion changes because of @ObservedObject
        if let cachedFileCount = searchViewModel.getCachedFileCount(for: item.searchResult.identifier.identifier) {
            result["Files"] = cachedFileCount == 1 ? "1 file" : "\(cachedFileCount) files"
        } else {
            // If not cached, trigger async fetch but don't block the UI
            Task {
                let _ = await searchViewModel.fetchFileCount(for: item.searchResult.identifier.identifier)
            }
        }
        
        return result
    }
}