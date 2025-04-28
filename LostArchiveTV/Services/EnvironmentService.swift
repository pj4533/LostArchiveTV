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
    
    /// Loads API keys from environment variables or Info.plist
    private func loadEnvironmentVariables() {
        Logger.network.debug("Loading API keys from environment variables...")
        
        // First try environment variables (useful for local development)
        let processInfo = ProcessInfo.processInfo
        cachedOpenAIKey = processInfo.environment[EnvironmentVariables.openAIKey]
        cachedPineconeKey = processInfo.environment[EnvironmentVariables.pineconeKey]
        cachedPineconeHost = processInfo.environment[EnvironmentVariables.pineconeHost]
        
        // If not found in environment, try Info.plist (for app store builds)
        if cachedOpenAIKey == nil {
            cachedOpenAIKey = Secrets.openAIKey
        }
        
        if cachedPineconeKey == nil {
            cachedPineconeKey = Secrets.pineconeKey
        }
        
        if cachedPineconeHost == nil {
            cachedPineconeHost = Secrets.pineconeHost
        }
        
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
