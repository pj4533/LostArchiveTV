//
//  VideoTransitionManagerTests.swift
//  LostArchiveTVTests
//
//  Created by Claude on 4/21/25.
//

import Testing
import AVKit
import SwiftUI
@testable import LATV

struct VideoTransitionManagerTests {
    
    @Test
    func nextVideoReady_defaultsToFalse() {
        // Arrange
        let transitionManager = VideoTransitionManager()
        
        // Assert
        #expect(transitionManager.nextVideoReady == false)
    }
    
    @Test
    func isTransitioning_defaultsToFalse() {
        // Arrange
        let transitionManager = VideoTransitionManager()
        
        // Assert
        #expect(transitionManager.isTransitioning == false)
    }
    
    @Test
    func nextPlayer_defaultsToNil() {
        // Arrange
        let transitionManager = VideoTransitionManager()
        
        // Assert
        #expect(transitionManager.nextPlayer == nil)
    }
    
    @Test
    func nextTitle_defaultsToEmptyString() {
        // Arrange
        let transitionManager = VideoTransitionManager()
        
        // Assert
        #expect(transitionManager.nextTitle == "")
    }
    
    @Test
    func nextCollection_defaultsToEmptyString() {
        // Arrange
        let transitionManager = VideoTransitionManager()
        
        // Assert
        #expect(transitionManager.nextCollection == "")
    }
    
    @Test
    func nextDescription_defaultsToEmptyString() {
        // Arrange
        let transitionManager = VideoTransitionManager()
        
        // Assert
        #expect(transitionManager.nextDescription == "")
    }
    
    @Test
    func nextIdentifier_defaultsToEmptyString() {
        // Arrange
        let transitionManager = VideoTransitionManager()
        
        // Assert
        #expect(transitionManager.nextIdentifier == "")
    }
}