# Pinecone Search Integration Summary for Swift App

This document outlines the full Pinecone implementation plan for integrating semantic search.

---

## 1. Swift Client Integration with Pinecone

The Swift app will:

- Generate an embedding from the search text using OpenAI.
- Query Pinecone using the embedding.
- Optionally apply metadata filters (e.g., by year or collection).

### Basic Swift Pinecone Query Example (async/await)

```swift
func queryPinecone(with embedding: [Double], metadataFilter: [String: Any]? = nil) async throws -> [PineconeMatch] {
    let url = URL(string: "https://your-index-name-your-project-id.svc.your-region.pinecone.io/query")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("Api-Key YOUR_PINECONE_API_KEY", forHTTPHeaderField: "Authorization")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    var body: [String: Any] = [
        "vector": embedding,
        "topK": 10,
        "includeMetadata": true
    ]

    if let metadataFilter = metadataFilter {
        body["filter"] = metadataFilter
    }

    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, _) = try await URLSession.shared.data(for: request)
    let response = try JSONDecoder().decode(PineconeQueryResponse.self, from: data)
    return response.matches
}
```

---

## 2. Generating Embedding from User's Search Query

Before querying Pinecone, generate an embedding of the user's search query using OpenAI.

### Swift Example for Generating Embedding with OpenAI (async/await)

```swift
func generateEmbedding(for text: String) async throws -> [Double] {
    let url = URL(string: "https://api.openai.com/v1/embeddings")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("Bearer YOUR_OPENAI_API_KEY", forHTTPHeaderField: "Authorization")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    let body: [String: Any] = [
        "input": text,
        "model": "text-embedding-3-large"
    ]

    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, _) = try await URLSession.shared.data(for: request)
    let response = try JSONDecoder().decode(OpenAIEmbeddingResponse.self, from: data)
    return response.data.first?.embedding ?? []
}

struct OpenAIEmbeddingResponse: Codable {
    struct EmbeddingData: Codable {
        let embedding: [Double]
    }
    let data: [EmbeddingData]
}
```

---

## 3. Metadata Filtering Strategy

Pinecone supports combining vector search with structured metadata filtering.

### Example Metadata Filters

**Year Filter (e.g., between 1970-1980):**

```json
{
  "year": {
    "$gte": 1970,
    "$lte": 1980
  }
}
```

**Collection Membership (e.g., classic_tv):**

```json
{
  "collection": {
    "$in": ["classic_tv"]
  }
}
```

**Combined Year and Collection:**

```json
{
  "year": {
    "$gte": 1970,
    "$lte": 1980
  },
  "collection": {
    "$in": ["classic_tv"]
  }
}
```

✅ Filters narrow the set of candidates before running similarity search.

---

## 4. Data Model for Each Vector in Pinecone

Every video vector stored in Pinecone includes:

- `id` (Internet Archive identifier)
- `values` (the embedding)
- `metadata`:
  - `title` (string)
  - `description` (string)
  - `subject` (array of strings)
  - `year` (integer)
  - `collection` (array of strings)

Example stored metadata:

```json
{
  "title": "Disco Inferno (1977)",
  "description": "Rare footage of NYC disco culture.",
  "subject": ["music", "disco", "1970s"],
  "year": 1977,
  "collection": ["opensource_movies", "best-disco-videos"]
}
```

---

## 5. Notes

- All Internet Archive videos are embedded using their title, description, and subject.
- Year is inferred if missing, using regex extraction from title or description.
- The `collection` is normalized to an array for reliable `$in` filters.
- You can build a SwiftUI interface that lets users:
  - Enter a search phrase
  - Set optional year range or select collections
  - Search using combined vector and metadata filters.

---

## 6. Requirements Summary

- Pinecone SDK/API (via direct HTTPS requests from Swift)
- OpenAI API for text embeddings (model: `text-embedding-3-large`)
- API keys securely stored (e.g., in app config or future Keychain)

