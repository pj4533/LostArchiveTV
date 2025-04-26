import Foundation
import OSLog

protocol PineconeServiceProtocol {
    func query(vector: [Float], filter: [String: Any]?, topK: Int) async throws -> [SearchResult]
}

class PineconeService: PineconeServiceProtocol {
    private let apiKey: String
    private let host: String
    private let session: URLSessionProtocol
    
    init(
        apiKey: String = APIKeys.pineconeKey,
        host: String = APIKeys.pineconeHost,
        session: URLSessionProtocol = URLSession.shared
    ) {
        self.apiKey = apiKey
        self.host = host
        self.session = session
    }
    
    private var baseURL: URL {
        // Constructs URL using the host
        URL(string: "\(host)/query")!
    }
    
    func query(vector: [Float], filter: [String: Any]? = nil, topK: Int = 20) async throws -> [SearchResult] {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.addValue("Api-Key \(apiKey)", forHTTPHeaderField: "Api-Key")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var requestBody: [String: Any] = [
            "vector": vector,
            "topK": topK,
            "includeMetadata": true
        ]
        
        if let filter = filter {
            requestBody["filter"] = filter
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        Logger.network.debug("Querying Pinecone with vector of size \(vector.count)")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            Logger.network.error("Invalid response type from Pinecone API")
            throw NetworkError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            Logger.network.error("Pinecone API error: \(httpResponse.statusCode)")
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NetworkError.serverError(statusCode: httpResponse.statusCode, message: errorString)
        }
        
        do {
            // Parse the response
            struct PineconeResponse: Decodable {
                struct Match: Decodable {
                    let id: String
                    let score: Float
                    let metadata: [String: String]?
                }
                let matches: [Match]
            }
            
            let pineconeResponse = try JSONDecoder().decode(PineconeResponse.self, from: data)
            
            Logger.network.debug("Received \(pineconeResponse.matches.count) matches from Pinecone")
            
            // Convert to SearchResult objects
            return pineconeResponse.matches.compactMap { match in
                // Extract collection from metadata or use default
                let collection = match.metadata?["collection"]?.components(separatedBy: ",").first ?? ""
                
                // Create ArchiveIdentifier from match
                let identifier = ArchiveIdentifier(
                    identifier: match.id,
                    collection: collection
                )
                
                return SearchResult(
                    identifier: identifier,
                    score: match.score,
                    metadata: match.metadata ?? [:]
                )
            }
        } catch {
            Logger.network.error("Failed to decode Pinecone response: \(error.localizedDescription)")
            throw NetworkError.parsingError(message: error.localizedDescription)
        }
    }
}