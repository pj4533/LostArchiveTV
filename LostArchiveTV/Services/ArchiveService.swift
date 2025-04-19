import Foundation

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
            throw ArchiveError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ArchiveError.networkError(NSError(domain: "Invalid response", code: 0))
            }
            
            guard 200..<300 ~= httpResponse.statusCode else {
                throw ArchiveError.serverError(statusCode: httpResponse.statusCode)
            }
            
            let decoder = JSONDecoder()
            let searchResponse = try decoder.decode(ArchiveSearchResponse.self, from: data)
            return searchResponse.response.docs
        } catch let decodingError as DecodingError {
            throw ArchiveError.decodingError(decodingError)
        } catch {
            throw ArchiveError.networkError(error)
        }
    }
    
    func getVideoDetails(identifier: String) async throws -> ArchiveVideoDetails {
        guard let url = URL(string: "https://archive.org/metadata/\(identifier)") else {
            throw ArchiveError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ArchiveError.networkError(NSError(domain: "Invalid response", code: 0))
            }
            
            guard 200..<300 ~= httpResponse.statusCode else {
                throw ArchiveError.serverError(statusCode: httpResponse.statusCode)
            }
            
            let decoder = JSONDecoder()
            return try decoder.decode(ArchiveVideoDetails.self, from: data)
        } catch let decodingError as DecodingError {
            throw ArchiveError.decodingError(decodingError)
        } catch {
            throw ArchiveError.networkError(error)
        }
    }
}