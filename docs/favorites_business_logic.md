# Favorites Business Logic

## Overview

Favorites is a user-curated collection system that allows users to bookmark videos for later viewing or organization. This document outlines the business rules and domain-specific knowledge required for working with the favorites system.

## Core Concepts

### Purpose and User Intent
- **Favorites are user-picked identifiers** that users want to keep track of while browsing
- Users add favorites **to avoid losing interesting content** as they explore other areas of the application
- Common use case: **Collecting videos to add to specific presets later**
- Favorites function as a **temporary holding area** for content curation

### User Experience
- Favorites can be **swiped through like any other feed** using the standard video navigation
- The favorites feed follows the same **bidirectional swipe patterns** as other feeds (up for next, down for previous)
- Users can **toggle favorite status** from any video player view

## Business Rules

### Ordering and Display
- **Favorites are displayed with the most recently added first** (newest-first ordering)
- This ordering is **maintained at all times** - both in memory and in persistence
- When adding a new favorite, it's **inserted at position 0** in the array
- The timestamp of addition is **stored and used for sorting**

### Storage and Persistence
- Favorites are **persisted in UserDefaults** as JSON-encoded data
- Each favorite stores:
  - Video identifier (unique key)
  - Collection name
  - Title and description
  - Video URL
  - Start position
  - **Timestamp of when it was added to favorites**
- The `totalFiles` count defaults to 1 when loading from storage (updated when video is played)

### Duplicate Prevention
- **No duplicate favorites allowed** - checked by identifier string equality
- Adding an already-favorited video is a **no-op** (silently ignored)
- Toggling a favorite that exists will **remove it**

### Pagination Support
- Favorites support **pagination with 20 items per page** by default
- The `getFavorites(page:pageSize:)` method maintains newest-first ordering
- Empty array returned if requesting beyond available pages

## Implementation Requirements

### Adding Favorites
1. Check if video is already a favorite (by identifier)
2. Create new CachedVideo with current timestamp
3. Insert at index 0 (beginning of array)
4. Save to UserDefaults
5. Log the addition

### Removing Favorites
1. Remove all videos matching the identifier
2. Save updated list to UserDefaults
3. Log the removal

### Loading Favorites
1. Clear existing favorites array
2. Load JSON data from UserDefaults
3. Convert StoredFavorite objects to CachedVideo instances
4. Sort by timestamp (newest first)
5. Handle missing timestamps gracefully

## Integration Points

### With Video Players
- Video player UI must show **favorite status indicator**
- Toggle action must be **available from all video views**
- Changes must be **immediately reflected** in UI

### With Feed System
- FavoritesFeedViewModel extends BaseFeedViewModel
- Supports standard **feed navigation patterns**
- Integrates with **preloading and caching** systems

### With Archive.org Content
- Must handle **cookie headers** for authenticated content
- Creates minimal **AVURLAsset** for video playback
- Reconstructs full **metadata objects** from stored data

## State Management

### Memory Cache
- Favorites are kept in memory as `@Published` array
- Changes trigger **SwiftUI updates** automatically
- Array is **source of truth** for current state

### Persistence Layer
- UserDefaults key: `"com.lostarchivetv.favorites"`
- Synchronous save after each modification
- Full reload on initialization

## Error Handling

### Graceful Degradation
- Missing favorites data returns **empty array** (not an error)
- Decoding failures are **logged but don't crash**
- Invalid video URLs are **skipped during loading**

### Data Migration
- No migration needed currently
- Future changes must **preserve existing favorites**
- Consider versioning if data structure changes

## Testing Considerations

### Key Scenarios
- Adding first favorite
- Adding duplicate (should be ignored)
- Removing non-existent favorite
- Pagination edge cases
- Timestamp ordering validation

### State Verification
- Verify UserDefaults persistence
- Check newest-first ordering maintained
- Validate pagination boundaries
- Ensure UI updates properly

## Future Considerations

- Potential for **organizing favorites into groups**
- Export favorites to **presets**
- Sync favorites across devices
- Favorite count limits (if needed)