import Foundation
import OSLog

extension PineconeService {
    // Create URL for vector fetch operations with query parameters
    private func vectorFetchURL(for identifiers: [String]) -> URL {
        var components = URLComponents(string: "\(host)/vectors/fetch")!
        components.queryItems = [
            URLQueryItem(name: "ids", value: identifiers.joined(separator: ","))
        ]
        return components.url!
    }
    
    // Finds similar videos for a given identifier by:
    // 1. Retrieving the vector for the identifier from Pinecone
    // 2. Using that vector to query for similar vectors
    func findSimilarByIdentifier(_ identifier: String, topK: Int = 20, offset: Int = 0) async throws -> [SearchResult] {
        // Log that we're finding similar videos
        Logger.network.debug("Finding similar videos for identifier: \(identifier), topK: \(topK), offset: \(offset)")
        
        // First, get the vector for this identifier from Pinecone
        let vectors = try await fetchVectorByIdentifier(identifier)
        
        // Ensure we actually got a vector back
        guard let vector = vectors.first?.values else {
            Logger.network.error("No vector found for identifier: \(identifier)")
            throw NetworkError.noData
        }
        
        // Log success and vector dimensions
        Logger.network.debug("Found vector with \(vector.count) dimensions for identifier \(identifier)")
        
        // Calculate the total number of results to fetch
        // We need to fetch offset + topK results to account for pagination
        let totalToFetch = offset + topK
        
        // Use the vector to search for similar videos
        // Pass nil for filter to get a broader range of results
        let allResults = try await query(vector: vector, topK: totalToFetch)
        
        // If offset is beyond the number of results, return empty array
        if offset >= allResults.count {
            Logger.network.info("Offset \(offset) is beyond available results (\(allResults.count)), returning empty array")
            return []
        }
        
        // Return the requested slice
        let endIndex = min(offset + topK, allResults.count)
        let paginatedResults = Array(allResults[offset..<endIndex])
        
        Logger.network.info("Returning \(paginatedResults.count) similar results (offset: \(offset), topK: \(topK))")
        return paginatedResults
    }
    
    // Fetches vector data for a single identifier
    private func fetchVectorByIdentifier(_ identifier: String) async throws -> [VectorData] {
        // Create the URL with query parameters
        let url = vectorFetchURL(for: [identifier])
        
        // Create the request as GET
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Set the Pinecone API key as the Authorization header
        request.addValue(apiKey, forHTTPHeaderField: "Api-Key")
        
        // Log the request we're making
        Logger.network.debug("Fetching vector for identifier: \(identifier) from \(url.absoluteString)")
        
        // Make the network request
        let (data, response) = try await session.data(for: request)
        
        // Check response is valid
        guard let httpResponse = response as? HTTPURLResponse else {
            Logger.network.error("Invalid response type from Pinecone API")
            throw NetworkError.invalidResponse
        }
        
        // Log response status
        Logger.network.debug("Pinecone Vector Fetch Response Status: \(httpResponse.statusCode)")
        
        // Check for successful response
        guard httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            Logger.network.error("Pinecone error (\(httpResponse.statusCode)): \(errorString)")
            throw NetworkError.serverError(statusCode: httpResponse.statusCode, message: errorString)
        }
        
        // Define nested types for decoding
        struct VectorResponse: Decodable {
            let id: String
            let values: [Float]
        }
        
        struct PineconeFetchResponse: Decodable {
            let vectors: [String: VectorResponse]
        }
        
        // Parse response
        do {
            // Show a preview of the response data (first 200 chars) for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                let previewLength = min(responseString.count, 200)
                let responsePreview = responseString.prefix(previewLength)
                Logger.network.debug("Pinecone Vector Fetch Preview: \(responsePreview)...")
            }
            
            let response = try JSONDecoder().decode(PineconeFetchResponse.self, from: data)
            
            // Convert to our VectorData model
            let vectors = response.vectors.map { VectorData(id: $0.key, values: $0.value.values) }
            
            // Log the number of vectors and dimensions
            if let firstVector = vectors.first {
                Logger.network.debug("Successfully fetched vector for \(identifier) with \(firstVector.values.count) dimensions")
            } else {
                Logger.network.warning("Vector response was successful but no vectors were found for \(identifier)")
            }
            
            return vectors
        } catch {
            Logger.network.error("Failed to decode Pinecone vector fetch response: \(error.localizedDescription)")
            
            // Log the raw data to help debug parsing errors
            if let responseString = String(data: data, encoding: .utf8) {
                let preview = responseString.prefix(500)
                Logger.network.error("Raw Pinecone response data (first 500 chars): \(preview)")
            }
            
            throw NetworkError.parsingError(message: error.localizedDescription)
        }
    }
}

// Model for vector data
struct VectorData {
    let id: String
    let values: [Float]
}