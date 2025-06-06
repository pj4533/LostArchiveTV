import Foundation

struct FavoritesFeedItem: FeedItem {
    let cachedVideo: CachedVideo
    
    var id: String { cachedVideo.id }
    var title: String { cachedVideo.title }
    var description: String? { cachedVideo.description }
    var thumbnailURL: URL? { cachedVideo.thumbnailURL }
    var metadata: [String: String] {
        var result: [String: String] = [:]
        // Add collection information
        result["Collection"] = cachedVideo.collection
        
        // Add time added information with formatting
        if let timestamp = cachedVideo.addedToFavoritesAt {
            result["Added"] = formatTimestamp(timestamp)
        } else {
            result["Added"] = "Unknown"
        }
        
        return result
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let days = components.day, days > 0 {
            if days >= 3 {
                // For dates older than 3 days, use date format
                let formatter = DateFormatter()
                formatter.dateFormat = "M/d/yyyy"
                return formatter.string(from: date)
            } else {
                // For 1-3 days
                return "\(days) day\(days > 1 ? "s" : "") ago"
            }
        } else if let hours = components.hour, hours > 0 {
            // For hours
            return "\(hours) hour\(hours > 1 ? "s" : "") ago"
        } else if let minutes = components.minute, minutes > 0 {
            // For minutes
            return "\(minutes) minute\(minutes > 1 ? "s" : "") ago"
        } else {
            // For just now
            return "Just now"
        }
    }
}