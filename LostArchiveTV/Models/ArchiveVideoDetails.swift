import Foundation
import OSLog

struct ArchiveVideoDetails: Codable {
    let metadata: ArchiveVideoMetadata
    let files: [ArchiveFile]
    
    // Helper method to find the best quality MP4 file
    func bestMP4File() -> ArchiveFile? {
        Logger.dataModel.debug("Finding best MP4 file among \(files.count) files for \(metadata.identifier)")
        
        let mp4Files = files.filter { $0.format?.lowercased() == "mpeg4" || $0.name.hasSuffix(".mp4") }
        Logger.dataModel.debug("Found \(mp4Files.count) MP4 files")
        
        let sortedFiles = mp4Files.sorted { Int($0.size ?? "0") ?? 0 > Int($1.size ?? "0") ?? 0 }
        
        if let best = sortedFiles.first {
            Logger.dataModel.info("Selected best MP4: \(best.name), size: \(best.sizeInMB ?? 0) MB")
            return best
        } else {
            Logger.dataModel.error("No MP4 files found for \(metadata.identifier)")
            return nil
        }
    }
    
    // Get direct video URL
    func videoURL() -> URL? {
        if let bestFile = bestMP4File()?.name {
            let urlString = "https://archive.org/download/\(metadata.identifier)/\(bestFile)"
            Logger.dataModel.debug("Generated video URL: \(urlString)")
            
            guard let url = URL(string: urlString) else {
                Logger.dataModel.error("Failed to create URL from string: \(urlString)")
                return nil
            }
            
            return url
        }
        Logger.dataModel.error("Could not get best MP4 file name for \(metadata.identifier)")
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