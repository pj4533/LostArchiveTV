# Simplifying Identifier Management Architecture

*Last Modified: May 14, 2025*

## Current Architecture

The app currently maintains two conceptual stores of identifiers:

1. **Global Identifiers List**: Managed by `UserSelectedIdentifiersManager.shared` and stored in UserDefaults
   - Serves as a copy of the currently selected preset's identifiers
   - Updated via `loadFromActivePreset()` when presets change
   - Has its own persistence mechanism with `saveIdentifiers()`
   - Requires synchronization with preset-specific identifiers

2. **Preset-Specific Identifiers**: Each `FeedPreset` has its own `savedIdentifiers` array
   - Stored within preset objects in UserDefaults via `HomeFeedPreferences`
   - Modified directly when working with preset detail views
   - Must be kept in sync with the global list

This dual-storage approach creates several challenges:

- Redundant storage of the same data
- Complex synchronization requirements
- Potential for data inconsistency if synchronization fails
- Confusing mental model (when are identifiers added to presets vs. the global list?)

## Proposed Simplification

We should simplify to a single source of truth for identifiers:

### 1. Make Presets the Only Source of Truth

- Remove the concept of a "global identifiers list"
- All identifier operations would be performed on presets directly
- When a preset is selected, the app simply uses that preset's identifiers
- No synchronization needed as there's only one copy of each identifier

### 2. Implementation Changes

#### UserSelectedIdentifiersManager

- Refactor as a facade for the currently selected preset
- Remove the in-memory `identifiers` array and related persistence
- Delegate all operations to the appropriate preset
- Methods like `addIdentifier()` and `removeIdentifier()` would modify the selected preset directly

```swift
func addIdentifier(_ newIdentifier: UserSelectedIdentifier) {
    guard let preset = HomeFeedPreferences.getSelectedPreset() else {
        return
    }
    
    var updatedPreset = preset
    
    // Don't add duplicates
    guard !updatedPreset.savedIdentifiers.contains(where: { $0.identifier == newIdentifier.identifier }) else {
        return
    }
    
    updatedPreset.savedIdentifiers.append(newIdentifier)
    HomeFeedPreferences.updatePreset(updatedPreset)
}
```

#### IdentifiersSettingsViewModel

- Remove the conditional logic for "global" vs "preset" identifiers
- Always work with a preset reference
- Default to the currently selected preset if none specified

```swift
// Init with the selected preset by default
init(preset: FeedPreset? = HomeFeedPreferences.getSelectedPreset()) {
    self.preset = preset
    if let preset = preset {
        self.identifiers = preset.savedIdentifiers
    } else {
        self.identifiers = []
    }
}
```

#### HomeFeedPreferences

- Add convenience methods for working with identifiers in the selected preset
- Example: `addIdentifierToSelectedPreset(identifier:)`

### 3. Benefits

- **Simpler mental model**: Identifiers always belong to presets
- **Reduced code complexity**: No synchronization logic needed
- **Better data integrity**: Single source of truth prevents inconsistencies
- **More predictable behavior**: Clear ownership of identifiers
- **Reduced storage**: No redundant storage of identifiers
- **Easier maintenance**: Fewer code paths and edge cases to test

### 4. Migration Path

1. Add the new preset-based methods first
2. Gradually replace calls to UserSelectedIdentifiersManager with preset-based operations
3. Once all references are updated, remove the global identifiers list
4. Update UI to reflect the new mental model (identifiers always shown in context of presets)

### 5. Areas to Update

1. **Identifier Addition**: When adding identifiers, always add to a specific preset
2. **Identifier Removal**: When removing identifiers, remove from a specific preset
3. **Identifier Views**: Always show identifiers in the context of their preset
4. **Navigation**: Update navigation flows to emphasize the preset relationship

### 6. Success Criteria

- No redundant data storage
- All identifier operations directly modify presets
- Clear and consistent user mental model
- Simplified codebase with fewer synchronization points