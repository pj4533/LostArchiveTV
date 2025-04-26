# Secure API Key Management for Xcode Cloud

This document outlines how to securely manage API keys in the LostArchiveTV app with Xcode Cloud.

## Problem

Environment variables set in Xcode Cloud are available at build time but not at runtime in the final app bundle. This causes API keys to be missing when the app is running.

## Solution

We use a combination of build-time environment variables and Info.plist entries to make the API keys available at runtime:

1. Store API keys as environment variables in Xcode Cloud
2. Use a build phase script to inject these variables into Info.plist
3. Read from both environment variables and Info.plist at runtime

## Implementation Steps

### 1. Set up environment variables in Xcode Cloud

1. Go to Xcode Cloud workflow settings
2. Add the following environment variables:
   - `OPENAI_API_KEY`: Your OpenAI API key
   - `PINECONE_API_KEY`: Your Pinecone API key
   - `PINECONE_HOST`: Your Pinecone host URL
3. Make sure they're marked as "secret" for security

### 2. Add a build phase script to your target

1. Open your project in Xcode
2. Select your target
3. Go to "Build Phases"
4. Click "+" and select "New Run Script Phase"
5. Move this phase after "Copy Bundle Resources"
6. Add the following script directly in the script text field (not as an external file):

```bash
# Only run if we have environment variables to inject
if [ -n "$OPENAI_API_KEY" ] || [ -n "$PINECONE_API_KEY" ] || [ -n "$PINECONE_HOST" ]; then
    echo "Injecting API keys into Info.plist"
    
    # Get the path to the Info.plist in the built products directory
    PLIST_PATH="${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}"
    
    # Check if the plist file exists
    if [ ! -f "$PLIST_PATH" ]; then
        echo "Error: Info.plist not found at $PLIST_PATH"
        exit 1
    fi
    
    # Add environment variables to Info.plist
    if [ -n "$OPENAI_API_KEY" ]; then
        /usr/libexec/PlistBuddy -c "Delete :OPENAI_API_KEY" "$PLIST_PATH" 2>/dev/null || true
        /usr/libexec/PlistBuddy -c "Add :OPENAI_API_KEY string $OPENAI_API_KEY" "$PLIST_PATH"
        echo "Added OPENAI_API_KEY to Info.plist"
    fi
    
    if [ -n "$PINECONE_API_KEY" ]; then
        /usr/libexec/PlistBuddy -c "Delete :PINECONE_API_KEY" "$PLIST_PATH" 2>/dev/null || true
        /usr/libexec/PlistBuddy -c "Add :PINECONE_API_KEY string $PINECONE_API_KEY" "$PLIST_PATH"
        echo "Added PINECONE_API_KEY to Info.plist"
    fi
    
    if [ -n "$PINECONE_HOST" ]; then
        /usr/libexec/PlistBuddy -c "Delete :PINECONE_HOST" "$PLIST_PATH" 2>/dev/null || true
        /usr/libexec/PlistBuddy -c "Add :PINECONE_HOST string $PINECONE_HOST" "$PLIST_PATH"
        echo "Added PINECONE_HOST to Info.plist"
    fi
    
    echo "Finished adding API keys to Info.plist for runtime access"
else
    echo "No API keys found in environment variables - skipping"
fi
```

### 3. Update EnvironmentService.swift

Update the EnvironmentService.swift file to check for keys in both environment variables and Info.plist:

```swift
private func loadEnvironmentVariables() {
    Logger.network.debug("Loading API keys from environment variables...")
    
    // First try environment variables (useful for local development)
    let processInfo = ProcessInfo.processInfo
    cachedOpenAIKey = processInfo.environment[EnvironmentVariables.openAIKey]
    cachedPineconeKey = processInfo.environment[EnvironmentVariables.pineconeKey]
    cachedPineconeHost = processInfo.environment[EnvironmentVariables.pineconeHost]
    
    // If not found in environment, try Info.plist (for app store builds)
    if cachedOpenAIKey == nil {
        cachedOpenAIKey = Bundle.main.infoDictionary?[EnvironmentVariables.openAIKey] as? String
    }
    
    if cachedPineconeKey == nil {
        cachedPineconeKey = Bundle.main.infoDictionary?[EnvironmentVariables.pineconeKey] as? String
    }
    
    if cachedPineconeHost == nil {
        cachedPineconeHost = Bundle.main.infoDictionary?[EnvironmentVariables.pineconeHost] as? String
    }
    
    // Log status (without exposing actual keys)
    Logger.network.debug("OpenAI API key status: \(self.cachedOpenAIKey != nil ? "Available" : "Missing")")
    Logger.network.debug("Pinecone API key status: \(self.cachedPineconeKey != nil ? "Available" : "Missing")")
    Logger.network.debug("Pinecone host status: \(self.cachedPineconeHost != nil ? "Available" : "Missing")")
}
```

### 4. Local Development Setup

For local development, you can:

1. Set environment variables in the Xcode scheme (already configured)
2. OR update the build script to also run during local development

## Security Considerations

1. **Never commit API keys to version control**
2. Keep using Xcode Cloud's secret environment variables
3. The keys will be embedded in the final app bundle, but this is necessary for the app to function
4. Consider implementing app-level encryption for the keys if higher security is needed
5. For App Store submissions, ensure your security measures comply with Apple's guidelines

## Testing

To test this setup:

1. Build the app with Xcode Cloud
2. Add debug logging to verify the keys are being read correctly at runtime
3. Test API functionality to ensure the keys are properly accessible

## Troubleshooting

If keys are still not available at runtime:

1. Verify the build script is running correctly (check build logs)
2. Check that the Info.plist path in the script matches your project's actual Info.plist
3. Ensure the EnvironmentService.swift is correctly reading from both sources
4. Add additional logging to debug where the key retrieval is failing

## Important Notes

- The build script is added directly in Xcode's build phase, not as an external file, to avoid sandbox permission issues
- This approach works for both local development and Xcode Cloud builds
- The script is designed to be robust with error handling and proper deletion before insertion