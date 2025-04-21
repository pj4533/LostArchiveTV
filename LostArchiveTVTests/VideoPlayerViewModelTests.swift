//
//  VideoPlayerViewModelTests.swift
//  LostArchiveTVTests
//
//  Created by Claude on 4/19/25.
//

import Testing
import AVKit
@testable import LATV

@MainActor
struct VideoPlayerViewModelTests {
    
    @Test
    func initialization_configuresInitialState() {
        // Arrange & Act
        let viewModel = VideoPlayerViewModel()
        
        // Assert
        #expect(viewModel.isInitializing)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.cacheProgress == 0.0)
        #expect(viewModel.cacheMessage == "Loading video library...")
    }
    
    @Test
    func loadRandomVideo_whenSuccess_updatesPlayerState() async throws {
        // Arrange
        let viewModel = VideoPlayerViewModel()
        
        // Make sure identifiers get loaded - the initialization task in the ViewModel loads them
        try? await Task.sleep(for: .seconds(0.5))
        
        // Initial state check
        viewModel.isLoading = false
        viewModel.errorMessage = "Previous error"
        
        // Act
        await viewModel.loadRandomVideo()
        
        // Assert
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.currentIdentifier != nil)
    }
    
    // Test loading a new video after a swipe action
    @Test
    func loadingNewVideo_afterSwipe_works() async {
        // Arrange
        let viewModel = VideoPlayerViewModel()
        
        // Wait for initial setup
        try? await Task.sleep(for: .seconds(0.5))
        
        // First load a video
        await viewModel.loadRandomVideo()
        
        // Act - simulate swipe by loading another video
        await viewModel.loadRandomVideo()
        
        // Wait for async work
        try? await Task.sleep(for: .seconds(0.5))
        
        // Assert - we can't verify internal state, but ensuring it doesn't crash is valuable
        #expect(viewModel.currentIdentifier != nil)
    }
}