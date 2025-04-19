import Foundation

struct ArchiveSearchResponse: Codable {
    let response: ArchiveResponse
}

struct ArchiveResponse: Codable {
    let docs: [ArchiveVideo]
}

struct ArchiveVideo: Identifiable, Codable {
    let identifier: String
    let title: String
    let description: String?
    let creator: String?
    let date: String?
    let thumbUrl: String?
    
    var id: String { identifier }
    
    // Computed property to get the video streaming URL
    var videoStreamUrl: URL? {
        URL(string: "https://archive.org/download/\(identifier)/\(identifier).mp4")
    }
    
    // Computed property for thumbnail URL if not directly provided
    var thumbnailUrl: URL {
        if let thumb = thumbUrl, let url = URL(string: thumb) {
            return url
        }
        return URL(string: "https://archive.org/services/img/\(identifier)")!
    }
    
    enum CodingKeys: String, CodingKey {
        case identifier, title, description, creator, date
        case thumbUrl = "thumb"
    }
}