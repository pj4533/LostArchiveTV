#!/bin/bash

echo "🚀 Running ci_pre_xcodebuild.sh to inject secrets..."

# Paths (adjust if your template file is elsewhere)
TEMPLATE_FILE="./LostArchiveTV/LostArchiveTV/SecretsTemplate.swift"
OUTPUT_FILE="./LostArchiveTV/LostArchiveTV/Secrets.swift"

# Exit build if any secret is missing
if [ -z "${OPENAI_API_KEY}" ] || [ -z "${PINECONE_API_KEY}" ] || [ -z "${PINECONE_HOST}" ]; then
  echo "❌ Error: One or more required secrets are not set."
  exit 1
fi

# Copy template and replace placeholders
cp "$TEMPLATE_FILE" "$OUTPUT_FILE"

# Replace variables in the copied file
sed -i '' "s|\${OPENAI_API_KEY}|${OPENAI_API_KEY}|g" "$OUTPUT_FILE"
sed -i '' "s|\${PINECONE_API_KEY}|${PINECONE_API_KEY}|g" "$OUTPUT_FILE"
sed -i '' "s|\${PINECONE_HOST}|${PINECONE_HOST}|g" "$OUTPUT_FILE"

echo "✅ Secrets.swift generated successfully."