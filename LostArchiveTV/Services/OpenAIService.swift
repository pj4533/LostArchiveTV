import Foundation
import OSLog

class OpenAIService {
    private let apiKey: String
    private let embeddingModel = "text-embedding-3-large"
    private let baseURL = URL(string: "https://api.openai.com/v1/embeddings")!
    
    init(apiKey: String = APIKeys.openAIKey) {
        self.apiKey = apiKey
        Logger.network.debug("OpenAIService initialized with API key length: \(apiKey.count) characters")
    }
    
    func generateEmbedding(for text: String) async throws -> [Float] {
        // Create and log configuration for URLSession
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0 // 30 second timeout
        config.timeoutIntervalForResource = 60.0 // 60 second timeout
        Logger.network.debug("OpenAI request timeouts: \(config.timeoutIntervalForRequest)s/\(config.timeoutIntervalForResource)s")
        
        // Create custom URLSession with this configuration
        let session = URLSession(configuration: config)
        
        // Configure request
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Log the URL and headers
        Logger.network.debug("OpenAI embedding request URL: \(baseURL.absoluteString)")
        let headers = request.allHTTPHeaderFields ?? [:]
        Logger.network.debug("OpenAI Request Headers: \(headers)")
        
        // Prepare body
        let requestBody: [String: Any] = [
            "input": text,
            "model": embeddingModel
        ]
        
        do {
            // Create and set request body
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            // Log truncated request for debugging
            let truncatedText = text.count > 50 ? text.prefix(50) + "..." : text
            Logger.network.debug("Generating embedding for text: \"\(truncatedText)\" with model: \(embeddingModel)")
            
            // Execute request with error handling
            Logger.network.debug("Starting OpenAI API request...")
            let (data, response) = try await session.data(for: request)
            Logger.network.debug("Received OpenAI API response")
            
            // Validate response type
            guard let httpResponse = response as? HTTPURLResponse else {
                Logger.network.error("Invalid response type from OpenAI API")
                throw NetworkError.invalidResponse
            }
            
            // Log response status and headers
            Logger.network.info("OpenAI Response Status: \(httpResponse.statusCode)")
            Logger.network.debug("OpenAI Response Headers: \(httpResponse.allHeaderFields)")
            
            // Handle error status
            guard httpResponse.statusCode == 200 else {
                let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                
                Logger.network.error("""
                OPENAI ERROR (\(httpResponse.statusCode)):
                URL: \(baseURL.absoluteString)
                Headers: \(httpResponse.allHeaderFields)
                Body: \(errorString)
                
                Original Request:
                Method: \(request.httpMethod ?? "")
                Headers: \(headers)
                Body: {"input": "\(truncatedText)...", "model": "\(embeddingModel)"}
                """)
                
                throw NetworkError.serverError(statusCode: httpResponse.statusCode, message: errorString)
            }
            
            // Log successful status
            Logger.network.debug("OpenAI API returned success status 200")
            
            // Parse the response
            struct EmbeddingResponse: Decodable {
                struct Data: Decodable {
                    let embedding: [Float]
                }
                let data: [Data]
            }
            
            // Log a preview of the raw response data for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                let previewLength = min(responseString.count, 500)
                let responsePreview = responseString.prefix(previewLength)
                Logger.network.debug("OpenAI Response Preview: \(responsePreview)...")
            }
            
            let embeddingResponse = try JSONDecoder().decode(EmbeddingResponse.self, from: data)
            guard let embedding = embeddingResponse.data.first?.embedding, !embedding.isEmpty else {
                Logger.network.error("Empty embedding returned from OpenAI")
                throw NetworkError.parsingError(message: "Empty embedding returned")
            }
            
            Logger.network.debug("Successfully generated embedding with \(embedding.count) dimensions")
            return embedding
        } catch let decodingError as DecodingError {
            // Handle specific decoding errors
            Logger.network.error("OpenAI JSON decoding error: \(decodingError)")
            
            // Try to log the raw response data
            if let data = decodingError.userInfo[NSDebugDescriptionErrorKey] as? Data,
               let responseString = String(data: data, encoding: .utf8) {
                Logger.network.error("Raw OpenAI response: \(responseString)")
            }
            
            throw NetworkError.parsingError(message: "Failed to decode: \(decodingError.localizedDescription)")
        } catch let urlError as URLError {
            // Handle network-specific errors
            let errorCode = urlError.errorCode
            let errorDescription = urlError.localizedDescription
            
            Logger.network.error("""
            OPENAI NETWORK ERROR:
            Code: \(errorCode)
            Description: \(errorDescription)
            URL: \(urlError.failureURLString ?? "unknown")
            """)
            
            throw NetworkError.serverError(
                statusCode: urlError.errorCode,
                message: "Network error: \(errorDescription)"
            )
        } catch {
            // Handle any other errors
            Logger.network.error("OpenAI unexpected error: \(error.localizedDescription)")
            throw error
        }
    }
}

// Network errors for better error handling
enum NetworkError: Error {
    case invalidResponse
    case serverError(statusCode: Int, message: String)
    case parsingError(message: String)
    case invalidURL
    case noData
}

extension NetworkError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server returned an invalid response"
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message)"
        case .parsingError(let message):
            return "Failed to parse server response: \(message)"
        case .invalidURL:
            return "The URL is invalid"
        case .noData:
            return "No data was returned from the server"
        }
    }
}