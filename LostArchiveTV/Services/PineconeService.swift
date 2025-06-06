import Foundation
import OSLog

class PineconeService {
    // Making these internal so they can be accessed from extensions
    let apiKey: String
    let host: String
    let session: URLSession
    
    init(
        apiKey: String? = nil,
        host: String? = nil
    ) {
        self.apiKey = apiKey ?? EnvironmentService.shared.pineconeKey
        self.host = host ?? EnvironmentService.shared.pineconeHost
        
        // Create a non-persisted, ephemeral session configuration
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
        
        Logger.network.debug("PineconeService initialized with ephemeral URLSession")
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
        
        // Perform the request using the dedicated session
        let (data, response) = try await session.data(for: request)
        
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
                // Handle collection which can be either string or array
                var collection = ""
                if let collectionArray = match.metadata?["collection"] as? [String], !collectionArray.isEmpty {
                    collection = collectionArray[0]
                } else if let collectionString = match.metadata?["collection"] as? String {
                    collection = collectionString.components(separatedBy: ",").first ?? ""
                }
                
                // Create ArchiveIdentifier from match
                let identifier = ArchiveIdentifier(
                    identifier: match.id,
                    collection: collection
                )
                
                // Convert metadata from [String: Any] to [String: String] for SearchResult
                var stringMetadata: [String: String] = [:]
                if let metadata = match.metadata {
                    for (key, value) in metadata {
                        if let stringValue = value as? String {
                            stringMetadata[key] = stringValue
                        } else if let arrayValue = value as? [String] {
                            stringMetadata[key] = arrayValue.joined(separator: ",")
                        } else if let intValue = value as? Int {
                            stringMetadata[key] = String(intValue)
                        } else {
                            stringMetadata[key] = String(describing: value)
                        }
                    }
                }
                
                return SearchResult(
                    identifier: identifier,
                    score: match.score,
                    metadata: stringMetadata
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
