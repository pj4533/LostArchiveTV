import Foundation
import OSLog

/// A service that manages access to API keys via environment variables
class EnvironmentService {
    // MARK: - Properties

    /// Shared singleton instance
    static let shared = EnvironmentService()

    /// Flag that indicates whether the app is currently in trim mode
    /// Services can check this flag to adjust behavior during video trimming
    static var isInTrimMode: Bool = false
    
    /// Environment variable names
    struct EnvironmentVariables {
        static let openAIKey = "OPENAI_API_KEY"
        static let pineconeKey = "PINECONE_API_KEY" 
        static let pineconeHost = "PINECONE_HOST"
        static let archiveCookie = "ARCHIVE_COOKIE"
        static let mixpanelToken = "MIXPANEL_TOKEN"
    }
    
    // MARK: - API Keys
    private var cachedOpenAIKey: String?
    private var cachedPineconeKey: String?
    private var cachedPineconeHost: String?
    private var cachedArchiveCookie: String?
    private var cachedMixpanelToken: String?
    
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
    
    /// Archive Cookie
    var archiveCookie: String {
        return cachedArchiveCookie ?? ""
    }
    
    /// The Mixpanel token
    var mixpanelToken: String {
        return cachedMixpanelToken ?? ""
    }
    
    /// Check if we have a valid archive cookie
    var hasArchiveCookie: Bool {
        guard let cookie = cachedArchiveCookie else { return false }
        return cookie != "${ARCHIVE_COOKIE}" && !cookie.isEmpty
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
        cachedArchiveCookie = processInfo.environment[EnvironmentVariables.archiveCookie]
        cachedMixpanelToken = processInfo.environment[EnvironmentVariables.mixpanelToken]
        
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
        
        if cachedArchiveCookie == nil {
            cachedArchiveCookie = Secrets.archiveCooke
        }
        
        if cachedMixpanelToken == nil {
            cachedMixpanelToken = Secrets.mixpanelToken
        }
        
        // Log status (without exposing actual keys)
        Logger.network.debug("OpenAI API key status: \((self.cachedOpenAIKey ?? "") != "${OPENAI_API_KEY}" && !(self.cachedOpenAIKey ?? "").isEmpty ? "Available" : "Missing")")
        Logger.network.debug("Pinecone API key status: \((self.cachedPineconeKey ?? "") != "${PINECONE_API_KEY}" && !(self.cachedPineconeKey ?? "").isEmpty ? "Available" : "Missing")")
        Logger.network.debug("Pinecone host status: \((self.cachedPineconeHost ?? "") != "${PINECONE_HOST}" && !(self.cachedPineconeHost ?? "").isEmpty ? "Available" : "Missing")")
        Logger.network.debug("Archive cookie status: \((self.cachedArchiveCookie ?? "") != "${ARCHIVE_COOKIE}" && !(self.cachedArchiveCookie ?? "").isEmpty ? "Available" : "Missing")")
        Logger.network.debug("Mixpanel token status: \((self.cachedMixpanelToken ?? "") != "${MIXPANEL_TOKEN}" && !(self.cachedMixpanelToken ?? "").isEmpty ? "Available" : "Missing")")

        // Validate that we have the required keys
        if (self.cachedOpenAIKey ?? "") == "${OPENAI_API_KEY}" || (self.cachedOpenAIKey ?? "").isEmpty {
            Logger.network.error("MISSING OPENAI API KEY: Application will fail when attempting semantic search")
        }
        
        if (self.cachedPineconeKey ?? "") == "${PINECONE_API_KEY}" || (self.cachedPineconeKey ?? "").isEmpty || (self.cachedPineconeHost ?? "") == "${PINECONE_HOST}" || (self.cachedPineconeHost ?? "").isEmpty {
            Logger.network.error("MISSING PINECONE CREDENTIALS: Application will fail when attempting semantic search")
        }
    }
}
