#!/bin/bash

echo "🚀 [START] Running ci_pre_xcodebuild.sh..."

# Where we think we are
echo "📂 Current working directory: $(pwd)"
echo "📄 Listing files in root:"
ls -al

# Project directory name (edit if needed)
PROJECT_DIR="LostArchiveTV"

# Paths
TEMPLATE_FILE="./${PROJECT_DIR}/SecretsTemplate.swift"
OUTPUT_FILE="./${PROJECT_DIR}/Secrets.swift"

echo "🔍 Expected template file path: ${TEMPLATE_FILE}"
echo "🔍 Expected output file path: ${OUTPUT_FILE}"

# Check if template file exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "❌ ERROR: SecretsTemplate.swift not found at ${TEMPLATE_FILE}"
    echo "📄 Files in ${PROJECT_DIR}:"
    ls -al "./${PROJECT_DIR}"
    exit 1
fi

# Check environment variables
echo "🔎 Checking environment variables:"
if [ -z "${OPENAI_API_KEY}" ]; then
    echo "❌ ERROR: OPENAI_API_KEY is not set."
else
    echo "✅ OPENAI_API_KEY is set. (Length: ${#OPENAI_API_KEY})"
fi

if [ -z "${PINECONE_API_KEY}" ]; then
    echo "❌ ERROR: PINECONE_API_KEY is not set."
else
    echo "✅ PINECONE_API_KEY is set. (Length: ${#PINECONE_API_KEY})"
fi

if [ -z "${PINECONE_HOST}" ]; then
    echo "❌ ERROR: PINECONE_HOST is not set."
else
    echo "✅ PINECONE_HOST is set. (Length: ${#PINECONE_HOST})"
fi

# Fail early if any required variable is missing
if [ -z "${OPENAI_API_KEY}" ] || [ -z "${PINECONE_API_KEY}" ] || [ -z "${PINECONE_HOST}" ]; then
    echo "❌ ERROR: One or more required environment variables are missing. Cannot continue."
    exit 1
fi

# Copy the template file to create Secrets.swift
echo "🛠️ Copying template file..."
cp "$TEMPLATE_FILE" "$OUTPUT_FILE"
echo "✅ Copied to ${OUTPUT_FILE}"

# Run replacements
echo "🔧 Replacing placeholders with environment variable values..."
sed -i '' "s|\${OPENAI_API_KEY}|${OPENAI_API_KEY}|g" "$OUTPUT_FILE"
sed -i '' "s|\${PINECONE_API_KEY}|${PINECONE_API_KEY}|g" "$OUTPUT_FILE"
sed -i '' "s|\${PINECONE_HOST}|${PINECONE_HOST}|g" "$OUTPUT_FILE"

# Verify output file exists
if [ -f "$OUTPUT_FILE" ]; then
    echo "✅ Secrets.swift generated successfully!"
    echo "📄 Contents preview:"
    cat "$OUTPUT_FILE"
else
    echo "❌ ERROR: Failed to create Secrets.swift!"
    exit 1
fi

echo "🎉 [END] ci_pre_xcodebuild.sh completed successfully."