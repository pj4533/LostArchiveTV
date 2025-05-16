<p align="center">
  <img src="lostarchivetv.gif" alt="LostArchiveTV Demo"/>
</p>

<h1 align="center">LostArchiveTV</h1>

<p align="center">
  <strong>Discover the Internet Archive in a TikTok-style experience</strong>
</p>

<p align="center">
  <a href="https://testflight.apple.com/join/5u5qyTWh"><img src="https://img.shields.io/badge/TestFlight-Join_Beta-blue?style=flat-square&logo=apple" alt="Join TestFlight"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="MIT License"></a>
  <img src="https://img.shields.io/badge/iOS-18.0+-orange?style=flat-square&logo=apple" alt="iOS 18.0+">
  <img src="https://img.shields.io/badge/Swift-5.9+-red?style=flat-square&logo=swift" alt="Swift 5.9+">
</p>

## ✨ Archive.org Meets Modern Interface

LostArchiveTV reimagines how we explore the vast [Internet Archive](https://archive.org) collection. Swipe through a curated stream of historical films, educational videos, and public domain treasures in a familiar, modern interface.

<p align="center">
  <table>
    <tr>
      <td align="center"><strong>🔄 Bidirectional</strong><br>Swipe up for new videos, down for history</td>
      <td align="center"><strong>✂️ Trim & Save</strong><br>Extract perfect clips to your Photos</td>
      <td align="center"><strong>🔍 Smart Search</strong><br>Find videos using natural language</td>
    </tr>
  </table>
</p>

## 🚀 Key Features

- **Intuitive Navigation** - TikTok-style interface with bidirectional swiping
- **Smart Preloading** - Videos buffer before you need them with visual indicators
- **Video Trimming** - Select and save the perfect moments with timeline scrubbing
- **Semantic Search** - Find videos using natural language queries
- **Content Discovery** - Find similar videos based on what you're watching
- **Favorites System** - Save interesting discoveries for later viewing
- **Time-Aware Playback** - Smart time offsets to show interesting parts of longer videos

## 🧠 Powered By

- **OpenAI** - For natural language understanding and semantic search
- **Pinecone** - Vector database for finding similar content
- **AVKit** - High-performance video playback and processing
- **SQLite** - Efficient storage of video identifiers and collections

## 🛠️ Technical Highlights

- **Advanced Preloading System** with priority-based loading for seamless transitions
- **Robust Caching** with automatic recovery mechanisms
- **Swift Concurrency** (async/await) for smooth performance
- **Protocol-Based Architecture** for consistent video control interfaces
- **Component-Based UI** for unified experience across features

## 📱 Requirements

- iOS 18.0+
- Xcode 16.0+
- Swift 5.9+
- API Keys for OpenAI and Pinecone (see [Setup](#-setup))

## 🔧 Setup

### API Keys

For the semantic search and similar videos features, you'll need:

1. OpenAI API key for embeddings
2. Pinecone API key and host for vector search

#### Developer Setup (Recommended)

1. Duplicate the "LostArchiveTV" scheme in Xcode (Product > Scheme > Manage Schemes)
2. Name it "LostArchiveTV-Dev" and add these environment variables:
   - `OPENAI_API_KEY`
   - `PINECONE_API_KEY`
   - `PINECONE_HOST`

#### CI/CD Setup

For Xcode Cloud or other CI systems, set the same environment variables in your build settings.

## 📚 Documentation

- Modern Swift Testing framework (not XCTest)
- Preloading and caching details in `docs/preloading_and_cacheing.md`

## 📄 License

MIT © [LostArchiveTV](LICENSE)