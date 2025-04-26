import Foundation
import OSLog

class PineconeService {
    private let apiKey: String
    private let host: String
    
    init(
        apiKey: String = APIKeys.pineconeKey,
        host: String = APIKeys.pineconeHost
    ) {
        self.apiKey = apiKey
        self.host = host
    }
    
    private var baseURL: URL {
        // Constructs URL using the host
        URL(string: "\(host)/query")!
    }
    
    func query(vector: [Float], filter: [String: Any]? = nil, topK: Int = 20) async throws -> [SearchResult] {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        
        // Log the URL we're calling
        Logger.network.debug("Pinecone Query URL: \(self.baseURL.absoluteString)")
        
        // Set the Pinecone API key as the Authorization header
        request.addValue(apiKey, forHTTPHeaderField: "Api-Key")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Log headers for debugging
        let headers = request.allHTTPHeaderFields ?? [:]
        Logger.network.debug("Pinecone Request Headers: \(headers)")
        
        var requestBody: [String: Any] = [
            "vector": vector,
            "topK": topK,
            "includeMetadata": true
        ]
        
        if let filter = filter {
            requestBody["filter"] = filter
        }
        
        // Create JSON data for request body
        let requestBodyData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = requestBodyData
        
        // Log a condensed version of the request body (vector is too large to log in full)
        var logRequestBody = requestBody
        if vector.count > 10 {
            // Just show the first few elements of the vector
            logRequestBody["vector"] = "[Vector with \(vector.count) dimensions: \(vector.prefix(3))...]"
        }
        Logger.network.debug("Pinecone Request Body: \(logRequestBody)")
        
        Logger.network.debug("Sending request to Pinecone with vector of size \(vector.count)")
        
        // Perform the request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Log response details
        guard let httpResponse = response as? HTTPURLResponse else {
            Logger.network.error("Invalid response type from Pinecone API")
            throw NetworkError.invalidResponse
        }
        
        // Always log the status code
        Logger.network.info("Pinecone Response Status: \(httpResponse.statusCode)")
        
        // Handle error responses
        guard httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            
            // Detailed error logging
            Logger.network.error("""
            PINECONE ERROR (\(httpResponse.statusCode)):
            URL: \(self.baseURL.absoluteString)
            Headers: \(httpResponse.allHeaderFields)
            Body: \(errorString)
            
            Original Request:
            Method: \(request.httpMethod ?? "")
            Headers: \(headers)
            """)
            
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
            
            // Log a preview of the raw response data for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                let previewLength = min(responseString.count, 500)
                let responsePreview = responseString.prefix(previewLength)
                Logger.network.debug("Pinecone Response Preview: \(responsePreview)...")
            }
            
            let pineconeResponse = try JSONDecoder().decode(PineconeResponse.self, from: data)
            
            Logger.network.debug("Received \(pineconeResponse.matches.count) matches from Pinecone")
            
            // Log a few sample matches for verification
            if !pineconeResponse.matches.isEmpty {
                let sampleCount = min(pineconeResponse.matches.count, 3)
                let sampleMatches = pineconeResponse.matches.prefix(sampleCount)
                for (index, match) in sampleMatches.enumerated() {
                    Logger.network.debug("Match \(index): id=\(match.id), score=\(match.score), metadata keys=\(match.metadata?.keys.joined(separator: ", ") ?? "none")")
                }
            }
            
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
            
            // Log the raw data to help debug parsing errors
            if let responseString = String(data: data, encoding: .utf8) {
                Logger.network.error("Raw Pinecone response data: \(responseString)")
            } else {
                Logger.network.error("Raw Pinecone response data could not be converted to string")
            }
            
            throw NetworkError.parsingError(message: error.localizedDescription)
        }
    }
}
