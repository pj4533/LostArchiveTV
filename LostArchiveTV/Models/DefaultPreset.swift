//
//  DefaultPreset.swift
//  LostArchiveTV
//
//  Created by Claude on 5/15/25.
//

import Foundation

/// Provides the default preset configuration for when the app is in "Default" mode
struct DefaultPreset {
    /// Static collection of default identifiers to include in the preset
    private static let defaultIdentifiers: [UserSelectedIdentifier] = []
    
    /// Static constant holding the default preset
    private static let defaultPreset = FeedPreset(
        id: "default-preset",
        name: "Default",
        enabledCollections: ["avgeeks", "classic_tv"],
        savedIdentifiers: defaultIdentifiers,
        isSelected: true
    )
    
    /// Get the default preset configured with "avgeeks" collection
    /// - Returns: A FeedPreset instance configured for default usage
    static func getPreset() -> FeedPreset {
        return defaultPreset
    }
    
    /// Add additional identifiers to the default preset by creating a new copy with updated identifiers
    /// - Parameter identifiers: The identifiers to include in the default preset
    /// - Returns: A new FeedPreset with the provided identifiers
    static func withIdentifiers(_ identifiers: [UserSelectedIdentifier]) -> FeedPreset {
        var preset = defaultPreset
        preset.savedIdentifiers = defaultIdentifiers + identifiers
        return preset
    }
}
