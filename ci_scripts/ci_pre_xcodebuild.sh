#!/bin/sh

echo "Creating LostArchiveTV/Secrets.xcconfig file..."

# Define correct path inside your project folder
SECRETS_FILE="$CI_PRIMARY_REPOSITORY_PATH/LostArchiveTV/Secrets.xcconfig"

# Write the xcconfig file
cat <<EOF > "$SECRETS_FILE"
OPENAI_API_KEY = $OPENAI_API_KEY
PINECONE_API_KEY = $PINECONE_API_KEY
PINECONE_HOST = $PINECONE_HOST
EOF

echo "Secrets.xcconfig created successfully at $SECRETS_FILE"