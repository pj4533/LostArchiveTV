import Foundation
import OSLog

struct PineconeMatch: Decodable {
    let id: String
    let score: Float
    let metadata: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case id, score, metadata
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        score = try container.decode(Float.self, forKey: .score)
        
        // Handle complex metadata structure
        if let metadataContainer = try? container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: .metadata) {
            var metadataDict: [String: Any] = [:]
            
            for key in metadataContainer.allKeys {
                // Try to decode as String
                if let stringValue = try? metadataContainer.decode(String.self, forKey: key) {
                    metadataDict[key.stringValue] = stringValue
                }
                // Try to decode as [String]
                else if let arrayValue = try? metadataContainer.decode([String].self, forKey: key) {
                    metadataDict[key.stringValue] = arrayValue
                }
                // Try to decode as Int
                else if let intValue = try? metadataContainer.decode(Int.self, forKey: key) {
                    metadataDict[key.stringValue] = intValue
                }
                // Default to null/nil if can't decode
                else {
                    Logger.network.debug("Could not decode metadata field: \(key.stringValue)")
                }
            }
            
            metadata = metadataDict
        } else {
            metadata = nil
        }
    }
}

// Helper type for dynamic keys in metadata
struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

struct PineconeResponse: Decodable {
    let matches: [PineconeMatch]
}