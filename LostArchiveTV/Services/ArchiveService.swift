import Foundation
import OSLog

enum ArchiveError: Error {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(statusCode: Int)
}

class ArchiveService {
    static let shared = ArchiveService()
    
    private init() {}
    
    func searchVideos(query: String = "funk", page: Int = 1, rows: Int = 50) async throws -> [ArchiveVideo] {
        Logger.network.debug("Searching videos with query: '\(query)', page: \(page), rows: \(rows)")
        var components = URLComponents(string: "https://archive.org/advancedsearch.php")!
        
        // Create mediatype:(movies) filter to get only videos
        let queryString = "\(query) AND mediatype:(movies)"
        
        components.queryItems = [
            URLQueryItem(name: "q", value: queryString),
            URLQueryItem(name: "fl[]", value: "identifier"),
            URLQueryItem(name: "fl[]", value: "title"),
            URLQueryItem(name: "fl[]", value: "description"),
            URLQueryItem(name: "fl[]", value: "creator"),
            URLQueryItem(name: "fl[]", value: "date"),
            URLQueryItem(name: "fl[]", value: "thumb"),
            URLQueryItem(name: "sort[]", value: "downloads desc"),
            URLQueryItem(name: "rows", value: "\(rows)"),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "output", value: "json")
        ]
        
        guard let url = components.url else {
            Logger.network.error("Failed to create URL for video search")
            throw ArchiveError.invalidURL
        }
        
        do {
            Logger.network.info("Requesting search from: \(url.absoluteString)")
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                Logger.network.error("Invalid response type received")
                throw ArchiveError.networkError(NSError(domain: "Invalid response", code: 0))
            }
            
            guard 200..<300 ~= httpResponse.statusCode else {
                Logger.network.error("Server error with status code: \(httpResponse.statusCode)")
                throw ArchiveError.serverError(statusCode: httpResponse.statusCode)
            }
            
            Logger.network.debug("Successfully received search response with status: \(httpResponse.statusCode)")
            let decoder = JSONDecoder()
            let searchResponse = try decoder.decode(ArchiveSearchResponse.self, from: data)
            Logger.network.info("Successfully decoded \(searchResponse.response.docs.count) videos from search response")
            return searchResponse.response.docs
        } catch let decodingError as DecodingError {
            Logger.network.error("Failed to decode search response: \(decodingError.localizedDescription)")
            throw ArchiveError.decodingError(decodingError)
        } catch {
            Logger.network.error("Network error during search: \(error.localizedDescription)")
            throw ArchiveError.networkError(error)
        }
    }
    
    func getVideoDetails(identifier: String) async throws -> ArchiveVideoDetails {
        Logger.network.debug("Getting video details for identifier: \(identifier)")
        guard let url = URL(string: "https://archive.org/metadata/\(identifier)") else {
            Logger.network.error("Failed to create URL for video details with identifier: \(identifier)")
            throw ArchiveError.invalidURL
        }
        
        do {
            Logger.network.info("Requesting video details from: \(url.absoluteString)")
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                Logger.network.error("Invalid response type received for video details")
                throw ArchiveError.networkError(NSError(domain: "Invalid response", code: 0))
            }
            
            guard 200..<300 ~= httpResponse.statusCode else {
                Logger.network.error("Server error when fetching video details: status code \(httpResponse.statusCode)")
                throw ArchiveError.serverError(statusCode: httpResponse.statusCode)
            }
            
            Logger.network.debug("Successfully received video details with status: \(httpResponse.statusCode)")
            let decoder = JSONDecoder()
            let details = try decoder.decode(ArchiveVideoDetails.self, from: data)
            Logger.network.info("Successfully decoded video details for: \(details.metadata.title)")
            return details
        } catch let decodingError as DecodingError {
            Logger.network.error("Failed to decode video details: \(decodingError.localizedDescription)")
            throw ArchiveError.decodingError(decodingError)
        } catch {
            Logger.network.error("Network error while fetching video details: \(error.localizedDescription)")
            throw ArchiveError.networkError(error)
        }
    }
}
