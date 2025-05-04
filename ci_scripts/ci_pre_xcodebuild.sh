#!/bin/bash

echo "🚀 [START] Running ci_pre_xcodebuild.sh..."

# --- Step 1: Move to the repo root ---
CURRENT_DIR=$(pwd)
if [[ "$CURRENT_DIR" == *"/ci_scripts" ]]; then
    echo "📂 Detected ci_scripts folder. Moving up to repo root..."
    cd ..
else
    echo "📂 Already at repo root: $CURRENT_DIR"
fi

echo "📂 Current working directory after adjustment: $(pwd)"
echo "📄 Top-level files:"
ls -al

# --- Step 2: Define project folder and file paths ---

PROJECT_DIR="LostArchiveTV"

TEMPLATE_FILE="./${PROJECT_DIR}/SecretsTemplate.swift"
OUTPUT_FILE="./${PROJECT_DIR}/Secrets.swift"

echo "🔍 Expected template file path: ${TEMPLATE_FILE}"
echo "🔍 Expected output file path: ${OUTPUT_FILE}"

# --- Step 3: Verify SecretsTemplate.swift exists ---

if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "❌ ERROR: SecretsTemplate.swift not found at ${TEMPLATE_FILE}"
    echo "📄 Contents of ${PROJECT_DIR}:"
    ls -al "./${PROJECT_DIR}" || echo "⚠️ Could not list contents of ${PROJECT_DIR}"
    exit 1
fi

# --- Step 4: Verify environment variables exist ---

echo "🔎 Checking environment variables..."

MISSING_ENV_VARS=false

if [ -z "${OPENAI_API_KEY}" ]; then
    echo "❌ ERROR: OPENAI_API_KEY is not set."
    MISSING_ENV_VARS=true
else
    echo "✅ OPENAI_API_KEY is set. (Length: ${#OPENAI_API_KEY})"
fi

if [ -z "${PINECONE_API_KEY}" ]; then
    echo "❌ ERROR: PINECONE_API_KEY is not set."
    MISSING_ENV_VARS=true
else
    echo "✅ PINECONE_API_KEY is set. (Length: ${#PINECONE_API_KEY})"
fi

if [ -z "${PINECONE_HOST}" ]; then
    echo "❌ ERROR: PINECONE_HOST is not set."
    MISSING_ENV_VARS=true
else
    echo "✅ PINECONE_HOST is set. (Length: ${#PINECONE_HOST})"
fi

if [ -z "${ARCHIVE_COOKIE}" ]; then
    echo "❌ ERROR: ARCHIVE_COOKIE is not set."
    MISSING_ENV_VARS=true
else
    echo "✅ ARCHIVE_COOKIE is set. (Length: ${#ARCHIVE_COOKIE})"
fi

if [ "$MISSING_ENV_VARS" = true ]; then
    echo "❌ ERROR: One or more environment variables are missing. Stopping build."
    exit 1
fi

# --- Step 5: Generate Secrets.swift ---

echo "🛠️ Copying SecretsTemplate.swift to Secrets.swift..."
cp "$TEMPLATE_FILE" "$OUTPUT_FILE"

if [ $? -ne 0 ]; then
    echo "❌ ERROR: Failed to copy SecretsTemplate.swift."
    exit 1
fi

# Escape sed-sensitive characters in secrets
ESCAPED_OPENAI_API_KEY=$(printf '%s\n' "$OPENAI_API_KEY" | sed 's/[&/\]/\\&/g')
ESCAPED_PINECONE_API_KEY=$(printf '%s\n' "$PINECONE_API_KEY" | sed 's/[&/\]/\\&/g')
ESCAPED_PINECONE_HOST=$(printf '%s\n' "$PINECONE_HOST" | sed 's/[&/\]/\\&/g')
ESCAPED_ARCHIVE_COOKIE=$(printf '%s\n' "$ARCHIVE_COOKIE" | sed 's/[&/\]/\\&/g')

echo "🔧 Replacing placeholders in Secrets.swift..."

sed -i '' "s|\${OPENAI_API_KEY}|${ESCAPED_OPENAI_API_KEY}|g" "$OUTPUT_FILE"
sed -i '' "s|\${PINECONE_API_KEY}|${ESCAPED_PINECONE_API_KEY}|g" "$OUTPUT_FILE"
sed -i '' "s|\${PINECONE_HOST}|${ESCAPED_PINECONE_HOST}|g" "$OUTPUT_FILE"
sed -i '' "s|\${ARCHIVE_COOKIE}|${ESCAPED_ARCHIVE_COOKIE}|g" "$OUTPUT_FILE"

# --- Step 6: Confirm output ---

if [ -f "$OUTPUT_FILE" ]; then
    echo "✅ Secrets.swift generated successfully!"
    echo "📄 First few lines of Secrets.swift:"
    head -n 10 "$OUTPUT_FILE"
else
    echo "❌ ERROR: Failed to create Secrets.swift!"
    exit 1
fi

# --- Step 7: Clean up ---

echo "🧹 Deleting SecretsTemplate.swift after generating Secrets.swift..."
rm -f "$TEMPLATE_FILE"

if [ $? -eq 0 ]; then
    echo "✅ Successfully deleted SecretsTemplate.swift."
else
    echo "⚠️ Warning: Failed to delete SecretsTemplate.swift."
fi

echo "🎉 [END] ci_pre_xcodebuild.sh completed successfully."