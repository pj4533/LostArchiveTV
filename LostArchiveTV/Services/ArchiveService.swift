//
//  ArchiveService.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import Foundation
import OSLog

actor ArchiveService {
    // MARK: - Metadata Loading
    func loadArchiveIdentifiers() async throws -> [String] {
        Logger.metadata.debug("Loading archive identifiers from bundle")
        guard let url = Bundle.main.url(forResource: "avgeeks_identifiers", withExtension: "json") else {
            Logger.metadata.error("Failed to find identifiers file")
            throw NSError(domain: "ArchiveService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Identifiers file not found"])
        }
        
        do {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Load data from the file
            let data = try Data(contentsOf: url)
            
            // Decode the identifiers
            let identifierObjects = try JSONDecoder().decode([ArchiveIdentifier].self, from: data)
            let identifiers = identifierObjects.map { $0.identifier }
            
            let loadTime = CFAbsoluteTimeGetCurrent() - startTime
            Logger.metadata.info("Loaded \(identifiers.count) identifiers in \(loadTime.formatted(.number.precision(.fractionLength(4)))) seconds")
            
            if identifiers.isEmpty {
                Logger.metadata.error("Identifiers array is empty after loading")
                throw NSError(domain: "ArchiveService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No identifiers found in file"])
            }
            
            return identifiers
        } catch {
            Logger.metadata.error("Failed to decode identifiers: \(error.localizedDescription)")
            throw error
        }
    }
    
    func fetchMetadata(for identifier: String) async throws -> ArchiveMetadata {
        let metadataURL = URL(string: "https://archive.org/metadata/\(identifier)")!
        Logger.network.debug("Fetching metadata from: \(metadataURL)")
        
        // Create URLSession configuration with cache
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        let session = URLSession(configuration: config)
        
        let requestStartTime = CFAbsoluteTimeGetCurrent()
        let (data, response) = try await session.data(from: metadataURL)
        let requestTime = CFAbsoluteTimeGetCurrent() - requestStartTime
        
        if let httpResponse = response as? HTTPURLResponse {
            Logger.network.debug("Metadata response: HTTP \(httpResponse.statusCode), size: \(data.count) bytes, time: \(requestTime.formatted(.number.precision(.fractionLength(4)))) seconds")
        }
        
        let decodingStartTime = CFAbsoluteTimeGetCurrent()
        let metadata = try JSONDecoder().decode(ArchiveMetadata.self, from: data)
        let decodingTime = CFAbsoluteTimeGetCurrent() - decodingStartTime
        
        Logger.metadata.debug("Decoded metadata with \(metadata.files.count) files in \(decodingTime.formatted(.number.precision(.fractionLength(4)))) seconds")
        return metadata
    }
    
    func getRandomIdentifier(from identifiers: [String]) -> String? {
        return identifiers.randomElement()
    }
    
    func findPlayableFiles(in metadata: ArchiveMetadata) -> [ArchiveFile] {
        let mp4Files = metadata.files.filter { $0.format == "MPEG4" || ($0.name.hasSuffix(".mp4")) }
        return mp4Files
    }
    
    func getFileDownloadURL(for file: ArchiveFile, identifier: String) -> URL? {
        return URL(string: "https://archive.org/download/\(identifier)/\(file.name)")
    }
    
    func estimateDuration(fromFile file: ArchiveFile) -> Double {
        var estimatedDuration: Double = 0
        
        if let lengthStr = file.length {
            Logger.metadata.debug("Found duration string in metadata: \(lengthStr)")
            
            // First, try to parse as a direct number of seconds (e.g., "1724.14")
            if let directSeconds = Double(lengthStr) {
                estimatedDuration = directSeconds
                Logger.metadata.debug("Parsed direct seconds value: \(estimatedDuration) seconds")
            }
            // If that fails, try to parse as HH:MM:SS format
            else if lengthStr.contains(":") {
                let components = lengthStr.components(separatedBy: ":")
                if components.count == 3, 
                   let hours = Double(components[0]),
                   let minutes = Double(components[1]),
                   let seconds = Double(components[2]) {
                    estimatedDuration = hours * 3600 + minutes * 60 + seconds
                    Logger.metadata.debug("Parsed HH:MM:SS format: \(estimatedDuration) seconds")
                }
            }
        }
        
        // Set a default approximate duration if we couldn't get one (30 minutes)
        if estimatedDuration <= 0 {
            estimatedDuration = 1800
            Logger.metadata.debug("Using default duration: \(estimatedDuration) seconds")
        } else {
            Logger.metadata.debug("Using extracted duration: \(estimatedDuration) seconds")
        }
        
        return estimatedDuration
    }
}
