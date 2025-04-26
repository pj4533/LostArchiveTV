# Pinecone Search Implementation Plan

## Overview
This implementation plan outlines the approach for integrating semantic search functionality into LostArchiveTV using OpenAI embeddings and Pinecone vector database. This feature will allow users to search for videos using natural language queries and filter results by collection or year.

## Architecture

### New Components
1. **APIKeysManager**: Secure management of API keys from a gitignored file
2. **OpenAIService**: Responsible for generating text embeddings using OpenAI's API
3. **PineconeService**: Handles vector search queries to Pinecone
4. **SearchManager**: Coordinates between OpenAI and Pinecone services
5. **SearchViewModel**: View model for search functionality (extending BaseVideoViewModel)
6. **SearchView**: UI for search input and results display
7. **SearchFilterView**: UI for filtering search results
8. **SearchResultsView**: Grid view of search results (similar to FavoritesView)

### Data Flow
1. User enters search query and optional filters in SearchView
2. SearchViewModel passes query to SearchManager
3. SearchManager uses OpenAIService to generate embedding
4. SearchManager constructs filter criteria and queries Pinecone using PineconeService
5. Pinecone returns relevant video identifiers and metadata
6. SearchViewModel processes results and updates UI
7. User can browse and play videos with same swipe experience as favorites

## Implementation Details

### 1. API Key Management

Create a gitignored file for API keys:

```swift
// APIKeys.swift (gitignored)
struct APIKeys {
    static let openAIKey = "YOUR_OPENAI_API_KEY"
    static let pineconeKey = "YOUR_PINECONE_API_KEY" 
    static let pineconeEnvironment = "gcp-starter" // or appropriate environment
    static let pineconeIndex = "lostarchivetv-7557a58"
}
```

Create a template file to include in source control:

```swift
// APIKeys.template.swift (committed to repo)
struct APIKeys {
    static let openAIKey = "YOUR_OPENAI_API_KEY"
    static let pineconeKey = "YOUR_PINECONE_API_KEY"
    static let pineconeEnvironment = "YOUR_PINECONE_ENVIRONMENT"
    static let pineconeIndex = "YOUR_PINECONE_INDEX"
}
```

Add to .gitignore:

```
# API Keys
LostArchiveTV/APIKeys.swift
```

### 2. Model Definitions

Create search-related models:

```swift
struct SearchResult: Identifiable, Equatable {
    let id = UUID()
    let identifier: ArchiveIdentifier
    let score: Float
    let metadata: [String: String]
    
    // Computed properties for UI display
    var title: String { metadata["title"] ?? identifier.identifier }
    var description: String { metadata["description"] ?? "" }
    var year: Int? { 
        guard let yearStr = metadata["year"], let year = Int(yearStr) else { return nil }
        return year
    }
    var collections: [String] {
        guard let collectionsStr = metadata["collection"] else { return [identifier.collection] }
        return collectionsStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

struct SearchFilter {
    var startYear: Int? = nil
    var endYear: Int? = nil
    
    // Convert filter to Pinecone query format
    func toPineconeFilter() -> [String: Any]? {
        var filter: [String: Any] = [:]
        var filterComponents: [[String: Any]] = []
        
        // Add year range filter if specified
        if let startYear = startYear, let endYear = endYear {
            filterComponents.append(["year": ["$gte": startYear, "$lte": endYear]])
        } else if let startYear = startYear {
            filterComponents.append(["year": ["$gte": startYear]])
        } else if let endYear = endYear {
            filterComponents.append(["year": ["$lte": endYear]])
        }
        
        // If no filters, return nil
        if filterComponents.isEmpty {
            return nil
        }
        
        // Combine filters with $and operator
        filter["$and"] = filterComponents
        return filter
    }
}
```

### 3. OpenAI Service

```swift
protocol OpenAIServiceProtocol {
    func generateEmbedding(for text: String) async throws -> [Float]
}

class OpenAIService: OpenAIServiceProtocol {
    private let apiKey: String
    private let embeddingModel = "text-embedding-3-large"
    private let baseURL = URL(string: "https://api.openai.com/v1/embeddings")!
    
    init(apiKey: String = APIKeys.openAIKey) {
        self.apiKey = apiKey
    }
    
    func generateEmbedding(for text: String) async throws -> [Float] {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "input": text,
            "model": embeddingModel
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, 
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "OpenAIService", 
                         code: (response as? HTTPURLResponse)?.statusCode ?? 500,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to generate embedding"])
        }
        
        // Parse the response
        struct EmbeddingResponse: Decodable {
            struct Data: Decodable {
                let embedding: [Float]
            }
            let data: [Data]
        }
        
        let embeddingResponse = try JSONDecoder().decode(EmbeddingResponse.self, from: data)
        guard let embedding = embeddingResponse.data.first?.embedding, !embedding.isEmpty else {
            throw NSError(domain: "OpenAIService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Empty embedding returned"])
        }
        
        return embedding
    }
}
```

### 4. Pinecone Service

```swift
protocol PineconeServiceProtocol {
    func query(vector: [Float], filter: [String: Any]?, topK: Int) async throws -> [SearchResult]
}

class PineconeService: PineconeServiceProtocol {
    private let apiKey: String
    private let baseURL: URL
    
    init(apiKey: String = APIKeys.pineconeKey) {
        self.apiKey = apiKey
        self.baseURL = URL(string: "https://lostarchivetv-7557a58.svc.aped-4627-b74a.pinecone.io/query")!
    }
    
    func query(vector: [Float], filter: [String: Any]? = nil, topK: Int = 20) async throws -> [SearchResult] {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.addValue("Api-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var requestBody: [String: Any] = [
            "vector": vector,
            "topK": topK,
            "includeMetadata": true
        ]
        
        if let filter = filter {
            requestBody["filter"] = filter
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "PineconeService", 
                        code: (response as? HTTPURLResponse)?.statusCode ?? 500,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to query Pinecone"])
        }
        
        // Parse the response
        struct PineconeResponse: Decodable {
            struct Match: Decodable {
                let id: String
                let score: Float
                let metadata: [String: String]?
            }
            let matches: [Match]
        }
        
        let pineconeResponse = try JSONDecoder().decode(PineconeResponse.self, from: data)
        
        // Convert to SearchResult objects
        return pineconeResponse.matches.compactMap { match in
            // Create ArchiveIdentifier from match
            let identifier = ArchiveIdentifier(
                identifier: match.id,
                collection: match.metadata?["collection"]?.components(separatedBy: ",").first ?? ""
            )
            
            return SearchResult(
                identifier: identifier,
                score: match.score,
                metadata: match.metadata ?? [:]
            )
        }
    }
}
```

### 5. Search Manager

```swift
protocol SearchManagerProtocol {
    func search(query: String, filter: SearchFilter?) async throws -> [SearchResult]
}

class SearchManager: SearchManagerProtocol {
    private let openAIService: OpenAIServiceProtocol
    private let pineconeService: PineconeServiceProtocol
    
    init(openAIService: OpenAIServiceProtocol = OpenAIService(),
         pineconeService: PineconeServiceProtocol = PineconeService()) {
        self.openAIService = openAIService
        self.pineconeService = pineconeService
    }
    
    func search(query: String, filter: SearchFilter? = nil) async throws -> [SearchResult] {
        guard !query.isEmpty else {
            return []
        }
        
        // Generate embedding for the query
        let embedding = try await openAIService.generateEmbedding(for: query)
        
        // Convert filter to Pinecone format
        let pineconeFilter = filter?.toPineconeFilter()
        
        // Query Pinecone
        let searchResults = try await pineconeService.query(
            vector: embedding,
            filter: pineconeFilter,
            topK: 20
        )
        
        return searchResults
    }
}
```

### 6. SearchViewModel

```swift
@MainActor
class SearchViewModel: BaseVideoViewModel, VideoProvider {
    private let searchManager: SearchManagerProtocol
    private let videoLoadingService: VideoLoadingServiceProtocol
    
    // Search state
    @Published var searchQuery = ""
    @Published var searchResults: [SearchResult] = []
    @Published var searchFilter = SearchFilter()
    @Published var isSearching = false
    @Published var showingPlayer = false
    @Published var errorMessage: String?
    
    // Navigation state
    private var currentIndex = 0
    @Published var currentResult: SearchResult?
    
    // For video transition/swipe support
    var transitionManager: VideoTransitionManager?
    
    init(searchManager: SearchManagerProtocol = SearchManager(),
         videoLoadingService: VideoLoadingServiceProtocol,
         playerManager: PlayerManager = PlayerManager()) {
        
        self.searchManager = searchManager
        self.videoLoadingService = videoLoadingService
        
        super.init()
    }
    
    func search() async {
        guard !searchQuery.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        errorMessage = nil
        
        do {
            let results = try await searchManager.search(query: searchQuery, filter: searchFilter)
            self.searchResults = results
            
            if !results.isEmpty {
                currentIndex = 0
                currentResult = results[0]
                await loadVideo(for: results[0].identifier)
            } else {
                errorMessage = "No results found"
                currentResult = nil
                player = nil
            }
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
            Logger.network.error("Search failed: \(error.localizedDescription)")
        }
        
        isSearching = false
    }
    
    func playVideoAt(index: Int) {
        guard index >= 0, index < searchResults.count else { return }
        
        isLoading = true
        currentIndex = index
        currentResult = searchResults[index]
        
        Task {
            await loadVideo(for: searchResults[index].identifier)
            
            // Start preloading of adjacent videos
            try? await Task.sleep(for: .seconds(0.5))
            await ensureVideosAreCached()
            
            isLoading = false
            showingPlayer = true
        }
    }
    
    private func loadVideo(for identifier: ArchiveIdentifier) async {
        do {
            isLoading = true
            
            let fileInfo = try await videoLoadingService.loadVideo(for: identifier)
            
            // Update metadata properties
            currentIdentifier = identifier.identifier
            if let result = searchResults.first(where: { $0.identifier.identifier == identifier.identifier }) {
                currentTitle = result.title
                currentDescription = result.description
            }
            
            isLoading = false
        } catch {
            errorMessage = "Failed to load video: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // MARK: - VideoProvider Protocol
    
    func getNextVideo() async -> CachedVideo? {
        guard !searchResults.isEmpty else { return nil }
        
        let nextIndex = (currentIndex + 1) % searchResults.count
        guard let nextIdentifier = nextIndex < searchResults.count ? searchResults[nextIndex].identifier : nil else {
            return nil
        }
        
        do {
            return try await videoLoadingService.getCachedVideo(for: nextIdentifier)
        } catch {
            return nil
        }
    }
    
    func getPreviousVideo() async -> CachedVideo? {
        guard !searchResults.isEmpty else { return nil }
        
        let prevIndex = (currentIndex - 1 + searchResults.count) % searchResults.count
        guard let prevIdentifier = prevIndex < searchResults.count ? searchResults[prevIndex].identifier : nil else {
            return nil
        }
        
        do {
            return try await videoLoadingService.getCachedVideo(for: prevIdentifier)
        } catch {
            return nil
        }
    }
    
    func updateToNextVideo() {
        let nextIndex = (currentIndex + 1) % searchResults.count
        currentIndex = nextIndex
        currentResult = searchResults[nextIndex]
    }
    
    func updateToPreviousVideo() {
        let prevIndex = (currentIndex - 1 + searchResults.count) % searchResults.count
        currentIndex = prevIndex
        currentResult = searchResults[prevIndex]
    }
    
    func isAtEndOfHistory() -> Bool {
        return searchResults.isEmpty || currentIndex >= searchResults.count - 1
    }
    
    func createCachedVideoFromCurrentState() async -> CachedVideo? {
        guard let identifier = currentIdentifier else { return nil }
        
        do {
            let archiveIdentifier = ArchiveIdentifier(identifier: identifier, collection: currentCollection ?? "")
            return try await videoLoadingService.getCachedVideo(for: archiveIdentifier)
        } catch {
            return nil
        }
    }
    
    func addVideoToHistory(_ video: CachedVideo) {
        // No-op for search results
    }
    
    func ensureVideosAreCached() async {
        guard !searchResults.isEmpty, let transitionManager = transitionManager else { return }
        
        Logger.caching.info("SearchViewModel: Preloading videos for navigation")
        
        async let nextTask = transitionManager.preloadNextVideo(provider: self)
        async let prevTask = transitionManager.preloadPreviousVideo(provider: self)
        
        _ = await (nextTask, prevTask)
    }
}
```

### 7. UI Implementation

#### SearchView
```swift
struct SearchView: View {
    @StateObject var viewModel: SearchViewModel
    @State private var showingFilters = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 16) {
                    searchBar
                    
                    if viewModel.isSearching {
                        loadingView
                    } else if let error = viewModel.errorMessage {
                        errorView(message: error)
                    } else if viewModel.searchResults.isEmpty {
                        emptyResultsView
                    } else {
                        searchResultsGrid
                    }
                }
                .navigationTitle("Search")
                .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showingFilters) {
                SearchFilterView(filter: $viewModel.searchFilter)
            }
            .fullScreenCover(isPresented: $viewModel.showingPlayer) {
                SwipeablePlayerView(provider: viewModel, 
                                   isPresented: $viewModel.showingPlayer)
            }
        }
    }
    
    private var searchBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search videos...", text: $viewModel.searchQuery)
                    .foregroundColor(.white)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onSubmit {
                        Task {
                            await viewModel.search()
                        }
                    }
                
                if !viewModel.searchQuery.isEmpty {
                    Button(action: {
                        viewModel.searchQuery = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(8)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
            
            Button {
                showingFilters.toggle()
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal)
    }
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            Text("Searching...")
                .foregroundColor(.white)
                .padding()
            Spacer()
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.yellow)
            Text(message)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task {
                    await viewModel.search()
                }
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
            Spacer()
        }
        .padding()
    }
    
    private var emptyResultsView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            if viewModel.searchQuery.isEmpty {
                Text("Search for videos from the Internet Archive")
            } else {
                Text("No results found")
            }
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }
    
    private var searchResultsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 160), spacing: 2)
            ], spacing: 2) {
                ForEach(Array(viewModel.searchResults.enumerated()), id: \.element.id) { index, result in
                    SearchResultCell(result: result, index: index, viewModel: viewModel)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

struct SearchResultCell: View {
    let result: SearchResult
    let index: Int
    let viewModel: SearchViewModel
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Reuse the thumbnail view from FavoritesView
            VideoThumbnailView(video: CachedVideo(
                identifier: result.identifier.identifier,
                title: result.title,
                description: result.description,
                collection: result.identifier.collection,
                thumbnailURL: URL(string: "https://archive.org/services/img/\(result.identifier.identifier)")
            ))
            .aspectRatio(1, contentMode: .fill)
            
            // Title overlay at bottom
            VStack(alignment: .leading) {
                Spacer()
                Text(result.title)
                    .lineLimit(2)
                    .font(.caption)
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.black.opacity(0.7))
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 160)
        .clipped()
        .onTapGesture {
            viewModel.playVideoAt(index: index)
        }
    }
}
```

#### SearchFilterView
```swift
struct SearchFilterView: View {
    @Binding var filter: SearchFilter
    @State private var startYear: String = ""
    @State private var endYear: String = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Year Range")) {
                    HStack {
                        TextField("From", text: $startYear)
                            .keyboardType(.numberPad)
                            .onChange(of: startYear) { _, newValue in
                                if let year = Int(newValue), year > 0 {
                                    filter.startYear = year
                                } else {
                                    filter.startYear = nil
                                }
                            }
                        
                        Text("to")
                        
                        TextField("To", text: $endYear)
                            .keyboardType(.numberPad)
                            .onChange(of: endYear) { _, newValue in
                                if let year = Int(newValue), year > 0 {
                                    filter.endYear = year
                                } else {
                                    filter.endYear = nil
                                }
                            }
                    }
                }
                
                Button("Reset Filters") {
                    filter = SearchFilter()
                    startYear = ""
                    endYear = ""
                }
                .foregroundColor(.red)
            }
            .onAppear {
                // Initialize UI from filter
                if let year = filter.startYear {
                    startYear = String(year)
                }
                if let year = filter.endYear {
                    endYear = String(year)
                }
            }
            .navigationTitle("Search Filters")
            .navigationBarItems(
                trailing: Button("Done") {
                    dismiss()
                }
            )
        }
    }
}
```

### 8. App Integration

Update `ContentView.swift` to include the search tab:

```swift
// In ContentView
@StateObject private var searchViewModel: SearchViewModel

init() {
    // Create the view model with the same favorites manager that will be used throughout the app
    let favManager = FavoritesManager()
    self._favoritesManager = StateObject(wrappedValue: favManager)
    
    let videoLoadingService = VideoLoadingService()
    let playerManager = PlayerManager()
    
    self._videoPlayerViewModel = StateObject(wrappedValue: VideoPlayerViewModel(
        favoritesManager: favManager,
        videoLoadingService: videoLoadingService,
        playerManager: playerManager
    ))
    
    self._favoritesViewModel = StateObject(wrappedValue: FavoritesViewModel(
        favoritesManager: favManager
    ))
    
    self._searchViewModel = StateObject(wrappedValue: SearchViewModel(
        videoLoadingService: videoLoadingService,
        playerManager: playerManager
    ))
}

var body: some View {
    TabView(selection: $selectedTab) {
        // Home Tab
        homeTab
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(0)
        
        // Search Tab
        SearchView(viewModel: searchViewModel)
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
            .tag(1)
        
        // Favorites Tab
        FavoritesView(viewModel: favoritesViewModel)
            .tabItem {
                Label("Favorites", systemImage: "heart.fill")
            }
            .tag(2)
    }
    .accentColor(.white)
    .preferredColorScheme(.dark)
    .onChange(of: selectedTab) { oldValue, newValue in
        handleTabChange(oldTab: oldValue, newTab: newValue)
    }
}

// Update tab change handler
private func handleTabChange(oldTab: Int, newTab: Int) {
    guard oldTab != newTab else { return }
    
    switch (oldTab, newTab) {
    case (0, _):
        // Leaving home tab
        if videoPlayerViewModel.isPlaying {
            videoPlayerViewModel.pausePlayback()
        }
    case (1, _):
        // Leaving search tab
        if searchViewModel.isPlaying {
            searchViewModel.pausePlayback()
        }
    case (2, _):
        // Leaving favorites tab
        if favoritesViewModel.isPlaying {
            favoritesViewModel.pausePlayback()
        }
    default:
        break
    }
}
```

## Implementation Plan

### Phase 1: Foundation & API Integration
1. Create APIKeys and template files
2. Implement OpenAIService for generating embeddings
3. Implement PineconeService for vector search
4. Implement SearchManager to coordinate between services
5. Add basic unit tests for API integrations

### Phase 2: View Model & Data Models
1. Create SearchResult and SearchFilter models
2. Implement SearchViewModel extending BaseVideoViewModel
3. Ensure proper integration with existing video loading services
4. Add tests for the SearchViewModel

### Phase 3: UI Implementation
1. Create SearchView with input field and results grid
2. Implement SearchFilterView for filtering results
3. Integrate with SwipeablePlayerView for consistent video playback
4. Update ContentView to include the new search tab
5. Add appropriate transitions between tabs

### Phase 4: Testing & Refinement
1. Test search functionality with various queries
2. Test filter functionality
3. Test integration with existing video playback system
4. Optimize performance for search results
5. Add caching for embeddings to reduce API calls
6. Add error handling and user feedback

