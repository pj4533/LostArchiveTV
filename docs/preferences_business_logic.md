# Preferences Business Logic

## Overview

Preferences manage user-configurable options that control the behavior of the LostArchiveTV application. This document outlines the business rules and domain-specific knowledge for the preferences system, with particular focus on the preset system that controls content discovery.

## Core Concepts

### Preferences Hierarchy
- **Preferences** are user-controlled settings that modify app behavior (toggles, selections, etc.)
- **Presets** are a specific type of preference that control **what content appears in the primary feed**
- Presets determine which Archive.org collections and specific identifiers are available for random selection

### Preset System Purpose
- Presets allow users to **customize their content discovery experience**
- Users can switch between different **content themes** quickly
- Each preset defines a **curated set of content sources**

## Business Rules

### Default Behavior
- **Default preset is enabled by default** when users first launch the app
- The default preset uses **standard Archive.org collections** defined in the database
- Users can **turn off the default preset** in preferences to use custom presets
- When default is disabled, users **must select a custom preset**

### Preset Selection Model
- **Only one preset can be active at a time** (mutually exclusive selection)
- Switching presets **immediately changes** the available content pool
- There must **always be at least one preset selected** (no "no preset" state)

### ALF Preset Example
- **ALF preset is included as a demonstration** of custom preset functionality
- Contains only the **"ALF - The Complete Series"** identifier from the avgeeks collection
- **Completely arbitrary choice** - meant to show users how focused presets work
- Serves as a **template** for users to understand preset capabilities

## Preset Structure

### Preset Components
```
FeedPreset:
- name: Display name for the preset
- enabledCollections: Array of collection identifiers to include
- savedIdentifiers: Specific video identifiers to always include
- isSelected: Whether this preset is currently active
```

### Content Selection Logic
1. If preset has **savedIdentifiers**, those take priority
2. If preset has **enabledCollections**, random content is selected from those collections
3. Empty arrays mean no content from that source type
4. Presets can combine both collections and specific identifiers

## State Management

### Persistence
- Presets are stored in **UserDefaults** as JSON-encoded array
- Key: `"FeedPresets"`
- Selected state is **persisted with each preset**

### Migration Strategy
- **Legacy settings are automatically migrated** to a "Current" preset
- Migration happens **once on first launch** with preset system
- Legacy collections become the enabledCollections of "Current" preset
- ALF preset is **added automatically once** via `hasAddedALFPresetKey` flag

### Selection Rules
- When selecting a preset, **all others are deselected**
- When deleting the selected preset, **ALF is preferred as next selection**
- If ALF unavailable, **first preset in list** becomes selected
- System **ensures a preset is always selected** after any operation

## Implementation Requirements

### Adding Custom Presets
1. Deselect all other presets if new one is marked as selected
2. Append to preset array
3. Ensure at least one preset remains selected
4. Save to UserDefaults

### Switching Presets
1. Mark target preset as selected
2. Mark all other presets as unselected
3. Update in-memory cache of enabled collections
4. Save to UserDefaults
5. Trigger content refresh in feeds

### Deleting Presets
1. Remove preset from array
2. If deleted preset was selected, auto-select replacement:
   - Prefer ALF preset if available
   - Otherwise select first preset
3. Ensure a preset remains selected
4. Save to UserDefaults

## Special Behaviors

### Use Default Collections Toggle
- Located at: `UserDefaults` key `"UseDefaultCollections"`
- When **true**: Uses database-defined default collections
- When **false**: Uses selected preset's configuration
- This is a **legacy compatibility layer** - presets are the preferred method

### Cache Initialization
- Settings cache **prevents recursive initialization** with flags
- Cache must be initialized **before reading any preferences**
- Updates must sync both **UserDefaults and in-memory cache**

## Integration Points

### With Feed System
- Selected preset determines **available content pool**
- Feed refreshes when **preset selection changes**
- Presets affect both **random selection** and **search results**

### With Settings UI
- Preset selection shown in **Settings > Identifiers**
- Custom preset creation/editing interface
- Visual indication of **currently active preset**

## Error Handling

### Robustness Requirements
- **Always maintain at least one preset** (never empty)
- **Always have one selected preset** (never no selection)
- Handle missing/corrupted preset data **gracefully**
- Fall back to **default collections** if preset system fails

### Data Validation
- Validate preset names are **non-empty**
- Ensure collection identifiers **exist in database**
- Verify saved identifiers have **valid format**

## ALF Preset Details

### Purpose
- **Educational example** showing how presets work
- Demonstrates **single-identifier preset** concept
- Shows users they can create **highly focused** content streams

### Implementation
```
Identifier: "ALF-The-Complete-Series"
Collection: "avgeeks"
File Count: 1
```

### User Expectations
- ALF preset shows **only ALF episodes**
- No random content mixed in
- Consistent, predictable content

## Future Considerations

- User-created custom presets
- Preset sharing between users
- Time-based preset switching (morning news, evening entertainment)
- Smart presets based on viewing history
- Preset combination/mixing options