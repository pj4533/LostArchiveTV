# Double-Speed Playback Feature Specification

## Overview

The double-speed playback feature allows users to temporarily increase video playback speed by using a tap-and-hold gesture on the video player. This feature enhances user experience by providing a quick way to speed through content without permanent changes to playback settings.

## User Experience

1. **Activation**: User taps and holds anywhere on the video player surface
2. **Feedback**: 
   - Visual indicator appears (FF icon) to show 2x speed mode is active
   - Haptic feedback identical to what's used for favorites is triggered
   - Video playback immediately switches to 2x normal speed
3. **Visual Indicator**:
   - Shows briefly when 2x mode is activated
   - Fades out with animation after a short period
   - Clear and intuitive icon (fast-forward symbol)
4. **Deactivation**:
   - User lifts finger from the screen
   - Video playback immediately returns to normal speed
   - No additional visual or haptic feedback on deactivation

## Technical Implementation

### Gesture Recognition

Implement a long-press gesture recognizer that:

- Activates immediately on press (no delay)
- Remains active as long as the user maintains contact
- Deactivates when contact ends
- Coexists with other gestures in the player interface

### Playback Speed Control

Modify the existing player management system to:

- Support temporary rate changes (2x normal speed)
- Revert to previous rate on gesture end
- Maintain consistent behavior across player transitions
- Remember and restore normal playback speed on deactivation

### Visual Feedback

Create a fast-forward icon overlay that:

- Appears centered in the player or in a non-intrusive corner
- Uses a standardized animation system for appearing
- Fades out with animation after a brief display period (approx. 1 second)
- Uses consistent styling with other player UI elements

### Haptic Feedback

Reuse the existing haptic feedback system:

- Trigger the same haptic feedback used when favoriting videos
- Ensure feedback works across all supported devices

## Implementation Components

### 1. VideoControlProvider Extension

Extend the `VideoControlProvider` protocol with methods for:
- Temporarily changing playback rate
- Triggering appropriate feedback

```swift
extension VideoControlProvider {
    func setTemporaryPlaybackRate(rate: Float)
    func resetPlaybackRate()
}
```

### 2. Long-Press Gesture Recognizer

Add a long-press gesture recognizer to the video player view:
- Integrate with existing `VideoGestureHandler`
- Configure to activate immediately on press
- Handle state changes to control playback speed

### 3. Visual Indicator Component

Create a reusable visual component for the fast-forward indicator:
- Implement as a SwiftUI view
- Support appear/disappear animations
- Position appropriately within the player view

### 4. Haptic Feedback Integration

Reuse existing haptic feedback mechanism:
- Identify the feedback generator used for favorites
- Ensure consistent usage across contexts

## Implementation Locations

### View Layer
- Modify `VideoGestureHandler` to include the long-press gesture recognizer
- Update `VideoLayersView` to support the 2x speed indicator overlay
- Ensure the gesture works with existing gesture handlers

### ViewModel Layer
- Extend `BaseVideoViewModel` with support for temporary speed changes
- Implement feedback triggering in a central location

### Service Layer
- Update `PlayerManager` to handle temporary rate changes
- Ensure rate changes don't persist across video transitions

## Implementation Strategy

To ensure consistent behavior across all player types with minimal code duplication:

1. **Protocol-Based Implementation**:
   - Leverage the existing `VideoControlProvider` protocol as the foundation
   - Implement core functionality once in protocol extensions
   - Each player type will inherit the behavior automatically

2. **Gesture Handling**:
   - Add the long-press gesture recognition to the base video view components
   - Configure gesture to coexist with existing tap and swipe gestures
   - Ensure gesture priorities are set correctly to avoid conflicts

3. **Visual Feedback Consistency**:
   - Create a single visual indicator component
   - Use consistent animation parameters across all player types
   - Ensure proper layering with existing player UI elements

## Considerations and Edge Cases

1. **Video Transitions**:
   - If the user is holding down while swiping to a new video, the new video should start at normal speed
   - The long-press state should not persist across video transitions

2. **Player Controls**:
   - Ensure the speed indicator doesn't interfere with other controls
   - Consider how this interacts with trim mode and other special player states

3. **Accessibility**:
   - Consider how this feature works with VoiceOver and other accessibility tools
   - Ensure the feature doesn't interfere with accessibility gestures

4. **Performance**:
   - Monitor performance impact of speed changes, especially on older devices
   - Ensure smooth transitions between normal and 2x speed

## Implementation Phases

1. **Phase 1: Core Functionality**
   - Implement temporary speed control in PlayerManager
   - Add long-press gesture recognition
   - Test basic functionality in the main player

2. **Phase 2: Visual and Haptic Feedback**
   - Create the fast-forward indicator
   - Implement animations
   - Add haptic feedback

3. **Phase 3: Cross-Player Integration**
   - Ensure functionality works in all player contexts
   - Test and fix any player-specific issues

4. **Phase 4: Testing and Refinement**
   - Test edge cases and transitions
   - Refine animations and timing
   - Performance optimization if needed