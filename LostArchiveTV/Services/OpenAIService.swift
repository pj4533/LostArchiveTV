import Foundation
import OSLog

// Protocol to make URLSession mockable
protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

protocol OpenAIServiceProtocol {
    func generateEmbedding(for text: String) async throws -> [Float]
}

class OpenAIService: OpenAIServiceProtocol {
    private let apiKey: String
    private let embeddingModel = "text-embedding-3-large"
    private let baseURL = URL(string: "https://api.openai.com/v1/embeddings")!
    private let session: URLSessionProtocol
    
    init(apiKey: String = APIKeys.openAIKey, session: URLSessionProtocol = URLSession.shared) {
        self.apiKey = apiKey
        self.session = session
    }
    
    func generateEmbedding(for text: String) async throws -> [Float] {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "input": text,
            "model": embeddingModel
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        Logger.network.debug("Generating embedding for text: \(text.prefix(50))")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            Logger.network.error("Invalid response type from OpenAI API")
            throw NetworkError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            Logger.network.error("OpenAI API error: \(httpResponse.statusCode)")
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NetworkError.serverError(statusCode: httpResponse.statusCode, message: errorString)
        }
        
        do {
            // Parse the response
            struct EmbeddingResponse: Decodable {
                struct Data: Decodable {
                    let embedding: [Float]
                }
                let data: [Data]
            }
            
            let embeddingResponse = try JSONDecoder().decode(EmbeddingResponse.self, from: data)
            guard let embedding = embeddingResponse.data.first?.embedding, !embedding.isEmpty else {
                Logger.network.error("Empty embedding returned from OpenAI")
                throw NetworkError.parsingError(message: "Empty embedding returned")
            }
            
            Logger.network.debug("Successfully generated embedding with \(embedding.count) dimensions")
            return embedding
        } catch {
            Logger.network.error("Failed to decode OpenAI response: \(error.localizedDescription)")
            throw NetworkError.parsingError(message: error.localizedDescription)
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