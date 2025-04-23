# Video Trimming Feature

LostArchiveTV allows users to trim and save segments of videos from the Internet Archive for later viewing. This document outlines the implementation and key components of this feature.

## Key Components

### User Interface

- **VideoTrimView**: Main trim interface with video player, timeline, and controls
- **TimelineView**: Visual representation of the video with thumbnails and trim handles
- **TrimHandle**: Draggable UI elements for selecting start and end points of clip
- **TrimDownloadView**: Modal progress view for downloading videos before trimming

### View Models

- **VideoTrimViewModel**: Coordinates the trim interface with:
  - Video playback controls
  - Timeline scrubbing
  - Handle positioning
  - Thumbnail generation
  - Save/export functionality
  - Auto-hiding play/pause button

### Services

- **VideoTrimManager**: Core service that handles:
  - Converting video between file formats
  - Extracting video segments based on time ranges
  - Generating timeline thumbnails
  - Saving to Photos library
  
- **VideoExportService**: Coordinates the export process:
  - Ensures proper file format
  - Handles Photos permissions
  - Reports progress and completion status
  
- **VideoSaveManager**: Handles downloading and saving complete videos:
  - Downloads videos with progress tracking
  - Manages temporary files
  - Integrates with Photos library

## User Workflow

1. User finds an interesting video while browsing Archive.org content
2. User initiates the trim operation
3. The TrimDownloadView shows progress while downloading the complete video
4. The VideoTrimView appears with the downloaded video
5. User adjusts the trim handles on the timeline to select desired segment
6. User can play/pause and scrub through the video to preview the selection
7. User taps "Save" to export the trimmed clip to Photos library
8. A success message appears when the export is complete

## Implementation Details

### Timeline Construction

The timeline displays video thumbnails to help users visually navigate. The thumbnails are generated using `AVAssetImageGenerator` to capture frames at regular intervals throughout the video. The thumbnails are positioned on a timeline relative to their timestamp in the video.

### Trim Handle Interaction

Trim handles can be dragged to adjust the selection. The handles:
- Cannot overlap or cross each other
- Update the playback position in real-time during dragging
- Cannot exceed the video duration boundaries
- Show visual feedback during dragging

### Auto-hiding Play/Pause Button

The play/pause button appears when the user taps the video and hides automatically after a few seconds of inactivity to provide an uncluttered viewing experience.

### Video Processing

The trimming process:
1. Creates a composition from the original video's selected range
2. Exports the composition to a new file
3. Saves the exported file to the Photos library using PHPhotoLibrary

### Recent Improvements

Recent commits have improved the trimming feature:
- Added auto-hiding play/pause button for better usability
- Fixed video duration display issues
- Improved trim preparation messaging
- Fixed crash when playing after right handle drag
- Enhanced thumbnail generation for longer videos

## Usage Tips

- For optimal performance, trim segments of 30 seconds or less
- The timeline thumbnails provide visual cues for scene changes
- Drag handles slowly for precise control
- The duration of the selected clip is displayed above the timeline