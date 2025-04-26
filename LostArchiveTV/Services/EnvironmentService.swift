import Foundation
import OSLog

/// A service that manages access to API keys via environment variables
class EnvironmentService {
    // MARK: - Properties
    
    /// Shared singleton instance
    static let shared = EnvironmentService()
    
    /// Environment variable names
    struct EnvironmentVariables {
        static let openAIKey = "OPENAI_API_KEY"
        static let pineconeKey = "PINECONE_API_KEY" 
        static let pineconeHost = "PINECONE_HOST"
    }
    
    // MARK: - API Keys
    private var cachedOpenAIKey: String?
    private var cachedPineconeKey: String?
    private var cachedPineconeHost: String?
    
    // MARK: - Initialization
    
    private init() {
        loadEnvironmentVariables()
    }
    
    // MARK: - Public API
    
    /// The OpenAI API key
    var openAIKey: String {
        return cachedOpenAIKey ?? ""
    }
    
    /// The Pinecone API key
    var pineconeKey: String {
        return cachedPineconeKey ?? ""
    }
    
    /// The Pinecone host URL
    var pineconeHost: String {
        return cachedPineconeHost ?? ""
    }
    
    // MARK: - Private Methods
    
    /// Loads API keys from environment variables
    private func loadEnvironmentVariables() {
        Logger.network.debug("Loading API keys from environment variables...")
        
        // Get values from environment variables
        cachedOpenAIKey = ProcessInfo.processInfo.environment[EnvironmentVariables.openAIKey]
        cachedPineconeKey = ProcessInfo.processInfo.environment[EnvironmentVariables.pineconeKey]
        cachedPineconeHost = ProcessInfo.processInfo.environment[EnvironmentVariables.pineconeHost]
        
        // Log status (without exposing actual keys)
        Logger.network.debug("OpenAI API key status: \(self.cachedOpenAIKey != nil ? "Available" : "Missing")")
        Logger.network.debug("Pinecone API key status: \(self.cachedPineconeKey != nil ? "Available" : "Missing")")
        Logger.network.debug("Pinecone host status: \(self.cachedPineconeHost != nil ? "Available" : "Missing")")
        
        // Validate that we have the required keys
        if self.cachedOpenAIKey == nil {
            Logger.network.error("MISSING OPENAI API KEY: Application will fail when attempting semantic search")
        }
        
        if self.cachedPineconeKey == nil || self.cachedPineconeHost == nil {
            Logger.network.error("MISSING PINECONE CREDENTIALS: Application will fail when attempting semantic search")
        }
    }
}