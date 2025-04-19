import Foundation

struct ArchiveVideoDetails: Codable {
    let metadata: ArchiveVideoMetadata
    let files: [ArchiveFile]
    
    // Helper method to find the best quality MP4 file
    func bestMP4File() -> ArchiveFile? {
        return files.filter { $0.format?.lowercased() == "mpeg4" || $0.name.hasSuffix(".mp4") }
                    .sorted { Int($0.size ?? "0") ?? 0 > Int($1.size ?? "0") ?? 0 }
                    .first
    }
    
    // Get direct video URL
    func videoURL() -> URL? {
        if let bestFile = bestMP4File()?.name {
            return URL(string: "https://archive.org/download/\(metadata.identifier)/\(bestFile)")
        }
        return nil
    }
}

struct ArchiveVideoMetadata: Codable {
    let identifier: String
    let title: String
    let description: String?
    let creator: String?
    let date: String?
}

struct ArchiveFile: Codable {
    let name: String
    let format: String?
    let size: String?
    let length: String?
    
    var sizeInMB: Double? {
        guard let sizeString = size, let sizeInt = Int(sizeString) else { return nil }
        return Double(sizeInt) / 1_000_000.0
    }
    
    var durationInSeconds: Double? {
        guard let lengthString = length else { return nil }
        let components = lengthString.split(separator: ":")
        if components.count == 3, 
           let hours = Double(components[0]),
           let minutes = Double(components[1]),
           let seconds = Double(components[2]) {
            return hours * 3600 + minutes * 60 + seconds
        }
        return nil
    }
}