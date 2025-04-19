
# Archive.org API Reference for iOS App

This document outlines the essential Archive.org API endpoints you'll use to build an engaging content discovery app. It includes details on how to query, what parameters to use, the format of the output, and links to the official documentation.

---

## 1. Advanced Search API

**Endpoint:**
```
https://archive.org/advancedsearch.php
```

**Purpose:**
Used to search the Archive.org collection with specific filters and return metadata about items.

**Method:** `GET`

**Parameters:**

- `q` — The query string, using Lucene syntax
- `fl[]` — Array of fields to return (`identifier`, `title`, `creator`, etc.)
- `sort[]` — Array for sorting (`downloads desc`, `date asc`, etc.)
- `rows` — Number of results per page (default: 50, max: 1000)
- `page` — Page number for pagination
- `output` — Format of the response (`json`, `xml`, `csv`)

**Example Request:**

```
https://archive.org/advancedsearch.php?q=collection:(prelinger)+AND+mediatype:(movies)&fl[]=identifier&fl[]=title&fl[]=description&sort[]=downloads+desc&rows=10&page=1&output=json
```

**Output Format:**

```json
{
  "response": {
    "docs": [
      {
        "identifier": "example_id",
        "title": "Example Title",
        "description": "Short description of the item."
      }
    ]
  }
}
```

**Documentation:**
[Advanced Search API Docs](https://archive.org/advancedsearch.php)

---

## 2. Metadata API

**Endpoint:**

```
https://archive.org/metadata/[identifier]
```

**Purpose:**

Used to retrieve detailed metadata and file listings for a specific item on Archive.org.

**Method:** `GET`

**Example Request:**

```
https://archive.org/metadata/driveinmovietads
```

**Output Format:**

```json
{
  "metadata": {
    "identifier": "driveinmovietads",
    "title": "Drive-In Movie Ads",
    "description": "Collection of old drive-in ads.",
    ...
  },
  "files": [
    {
      "name": "movie.mp4",
      "format": "MPEG4",
      "size": "123456789",
      "length": "00:01:23"
    }
  ]
}
```

**Use this to:**

- Get media file URLs (MP4, MP3, PDF)
- Find thumbnails and previews
- Display full metadata details in your app

**Documentation:**
[Metadata API Docs](https://archive.org/services/docs/api/metadata.html)

---

## 3. Search UI for Manual Exploration (Optional)

While not an API, this can help you manually explore queries you might use:
[https://archive.org/advancedsearch.php](https://archive.org/advancedsearch.php)

---

## Notes

- Respect Archive.org’s bandwidth and API rate limits.
- Always cache or paginate results to avoid abuse.
- You can download media files directly using the base URL:
  ```
  https://archive.org/download/[identifier]/[filename]
  ```

---

## Bonus Resources

- [General API Overview](https://archive.org/services/docs/)
- [Advanced Search Syntax](https://archive.org/advancedsearch.php#raw)
- [Wayback Machine APIs (if needed)](https://archive.org/help/wayback_api.php)
