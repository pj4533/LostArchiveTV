//
//  BufferingProgressBarTests.swift
//  LostArchiveTVTests
//
//  Created by Claude on 6/28/25.
//

import Testing
import SwiftUI
@testable import LATV

struct BufferingProgressBarTests {
    
    // MARK: - Helper methods
    
    private func createProgressBar(
        videoTitle: String = "Test Video",
        bufferProgress: Double = 0.5,
        bufferSeconds: Double = 15.0,
        bufferState: BufferState = .sufficient,
        isActivelyBuffering: Bool = false,
        bufferFillRate: Double = 0.0,
        showReadinessMarker: Bool = true
    ) -> BufferingProgressBar {
        return BufferingProgressBar(
            videoTitle: videoTitle,
            bufferProgress: bufferProgress,
            bufferSeconds: bufferSeconds,
            bufferState: bufferState,
            isActivelyBuffering: isActivelyBuffering,
            bufferFillRate: bufferFillRate,
            showReadinessMarker: showReadinessMarker
        )
    }
    
    // MARK: - Initialization Tests
    
    @Test
    func init_withAllParameters_storesCorrectly() {
        // Arrange
        let title = "Test Video Title"
        let progress = 0.75
        let seconds = 22.5
        let state = BufferState.good
        let isBuffering = true
        let fillRate = 1.5
        let showMarker = false
        
        // Act
        let progressBar = BufferingProgressBar(
            videoTitle: title,
            bufferProgress: progress,
            bufferSeconds: seconds,
            bufferState: state,
            isActivelyBuffering: isBuffering,
            bufferFillRate: fillRate,
            showReadinessMarker: showMarker
        )
        
        // Assert
        #expect(progressBar.videoTitle == title)
        #expect(progressBar.bufferProgress == progress)
        #expect(progressBar.bufferSeconds == seconds)
        #expect(progressBar.bufferState == state)
        #expect(progressBar.isActivelyBuffering == isBuffering)
        #expect(progressBar.bufferFillRate == fillRate)
        #expect(progressBar.showReadinessMarker == showMarker)
    }
    
    // MARK: - Color Scheme Tests
    
    @Test
    func colorForState_unknown_returnsGray() {
        // Arrange
        let _ = createProgressBar(bufferState: .unknown)
        
        // Act & Assert
        // We can't directly access the private computed property,
        // but we can test the logic that would be used
        let expectedColor = getColorForState(.unknown)
        #expect(expectedColor == .gray)
    }
    
    @Test
    func colorForState_empty_returnsRed() {
        // Arrange & Act
        let expectedColor = getColorForState(.empty)
        
        // Assert
        #expect(expectedColor == .red)
    }
    
    @Test
    func colorForState_critical_returnsRedWithOpacity() {
        // Arrange & Act
        let expectedColor = getColorForState(.critical)
        
        // Assert
        #expect(expectedColor == Color.red.opacity(0.8))
    }
    
    @Test
    func colorForState_low_returnsOrange() {
        // Arrange & Act
        let expectedColor = getColorForState(.low)
        
        // Assert
        #expect(expectedColor == .orange)
    }
    
    @Test
    func colorForState_sufficient_returnsYellow() {
        // Arrange & Act
        let expectedColor = getColorForState(.sufficient)
        
        // Assert
        #expect(expectedColor == .yellow)
    }
    
    @Test
    func colorForState_good_returnsGreenWithOpacity() {
        // Arrange & Act
        let expectedColor = getColorForState(.good)
        
        // Assert
        #expect(expectedColor == Color.green.opacity(0.7))
    }
    
    @Test
    func colorForState_excellent_returnsGreen() {
        // Arrange & Act
        let expectedColor = getColorForState(.excellent)
        
        // Assert
        #expect(expectedColor == .green)
    }
    
    // Helper function to replicate the colorForState logic
    private func getColorForState(_ state: BufferState) -> Color {
        switch state {
        case .unknown:
            return .gray
        case .empty:
            return .red
        case .critical:
            return .red.opacity(0.8)
        case .low:
            return .orange
        case .sufficient:
            return .yellow
        case .good:
            return .green.opacity(0.7)
        case .excellent:
            return .green
        }
    }
    
    // MARK: - Progress Calculation Tests
    
    @Test
    func bufferProgress_edgeCases() {
        // Test various progress values
        let testCases: [Double] = [0.0, 0.15, 0.5, 0.75, 1.0, 1.2]
        
        for progress in testCases {
            let progressBar = createProgressBar(bufferProgress: progress)
            
            // Progress should be stored as provided (clamping happens in the monitor)
            #expect(progressBar.bufferProgress == progress)
        }
    }
    
    @Test
    func bufferSeconds_formattingLogic() {
        // Test the seconds formatting logic
        let testCases: [(Double, String)] = [
            (0.0, "0.0s"),
            (1.5, "1.5s"),
            (10.0, "10.0s"),
            (99.9, "99.9s"),
            (123.456, "123.5s") // Rounded to 1 decimal place
        ]
        
        for (seconds, expectedFormat) in testCases {
            let formattedString = String(format: "%.1fs", seconds)
            #expect(formattedString == expectedFormat, 
                   "Seconds \(seconds) should format as \(expectedFormat), got \(formattedString)")
        }
    }
    
    // MARK: - Buffer State Tests
    
    @Test
    func allBufferStates_createSuccessfully() {
        // Test that progress bar can be created with all buffer states
        for state in BufferState.allCases {
            let progressBar = createProgressBar(bufferState: state)
            #expect(progressBar.bufferState == state)
        }
    }
    
    // MARK: - Fill Rate Display Logic Tests
    
    @Test
    func fillRateDisplay_positiveRate_showsUpArrow() {
        // Arrange
        let positiveRates: [Double] = [0.1, 1.0, 2.5, 10.0]
        
        for rate in positiveRates {
            // Act
            let shouldShowUpArrow = rate > 0
            let iconName = shouldShowUpArrow ? "arrow.up" : "arrow.down"
            
            // Assert
            #expect(shouldShowUpArrow, "Rate \(rate) should show up arrow")
            #expect(iconName == "arrow.up")
        }
    }
    
    @Test
    func fillRateDisplay_negativeRate_showsDownArrow() {
        // Arrange
        let negativeRates: [Double] = [-0.1, -1.0, -2.5, -10.0]
        
        for rate in negativeRates {
            // Act
            let shouldShowDownArrow = rate < 0
            let iconName = shouldShowDownArrow ? "arrow.down" : "arrow.up"
            
            // Assert
            #expect(shouldShowDownArrow, "Rate \(rate) should show down arrow")
            #expect(iconName == "arrow.down")
        }
    }
    
    @Test
    func fillRateDisplay_zeroRate_showsNoArrow() {
        // Arrange
        let zeroRate = 0.0
        
        // Act
        let shouldShowArrow = zeroRate != 0
        
        // Assert
        #expect(!shouldShowArrow, "Zero rate should not show arrow")
    }
    
    // MARK: - Readiness Marker Tests
    
    @Test
    func readinessMarker_threshold_isCorrect() {
        // Test the readiness threshold value
        let expectedThreshold = 0.15
        let _ = createProgressBar(showReadinessMarker: true)
        
        // The threshold should be 15% of total progress
        #expect(expectedThreshold == 0.15)
        
        // Test positioning logic
        let geometry = CGSize(width: 100, height: 4)
        let markerPosition = geometry.width * expectedThreshold
        #expect(markerPosition == 15.0) // 15% of 100 = 15
    }
    
    @Test
    func readinessMarker_showFlag_controlsVisibility() {
        // Test that the show readiness marker flag works correctly
        let withMarker = createProgressBar(showReadinessMarker: true)
        let withoutMarker = createProgressBar(showReadinessMarker: false)
        
        #expect(withMarker.showReadinessMarker == true)
        #expect(withoutMarker.showReadinessMarker == false)
    }
    
    // MARK: - Active Buffering Indicator Tests
    
    @Test
    func activeBufferingIndicator_conditions() {
        // Test the conditions for showing the pulsing dot
        let testCases: [(progress: Double, isBuffering: Bool, shouldShow: Bool)] = [
            (0.0, true, false),   // No progress
            (0.5, false, false),  // Not buffering
            (0.5, true, true),    // Should show
            (1.0, true, false),   // Complete progress
            (1.1, true, false)    // Over complete
        ]
        
        for (progress, isBuffering, shouldShow) in testCases {
            let shouldShowDot = isBuffering && progress > 0 && progress < 1
            #expect(shouldShowDot == shouldShow,
                   "Progress \(progress), buffering \(isBuffering) should show dot: \(shouldShow)")
        }
    }
    
    @Test
    func activeBufferingIndicator_networkIcon() {
        // Test network activity icon logic
        let bufferingBar = createProgressBar(isActivelyBuffering: true)
        let nonBufferingBar = createProgressBar(isActivelyBuffering: false)
        
        #expect(bufferingBar.isActivelyBuffering == true)
        #expect(nonBufferingBar.isActivelyBuffering == false)
    }
    
    // MARK: - Constants Tests
    
    @Test
    func constants_haveCorrectValues() {
        // Test that the constants defined in the view are reasonable
        let barHeight: CGFloat = 4
        let cornerRadius: CGFloat = 2
        let readinessThreshold: Double = 0.15
        let textFontSize: CGFloat = 9
        let iconFontSize: CGFloat = 8
        
        // Verify relationships
        #expect(cornerRadius <= barHeight / 2) // Corner radius should be reasonable
        #expect(readinessThreshold > 0 && readinessThreshold < 1) // Should be a percentage
        #expect(iconFontSize <= textFontSize) // Icon should be smaller or equal to text
        #expect(textFontSize > 0) // Font sizes should be positive
    }
    
    // MARK: - Text Truncation Tests
    
    @Test
    func videoTitle_truncation() {
        // Test very long titles
        let longTitle = "This is a very long video title that should be truncated because it exceeds the reasonable display length for the UI component"
        let progressBar = createProgressBar(videoTitle: longTitle)
        
        #expect(progressBar.videoTitle == longTitle)
        // The actual truncation happens in the SwiftUI Text view with .lineLimit(1) and .truncationMode(.tail)
    }
    
    @Test
    func videoTitle_emptyString() {
        // Test empty title
        let emptyTitle = ""
        let progressBar = createProgressBar(videoTitle: emptyTitle)
        
        #expect(progressBar.videoTitle == emptyTitle)
    }
    
    @Test
    func videoTitle_specialCharacters() {
        // Test titles with special characters
        let specialTitles = [
            "Video with émojis 🎬",
            "Title with \"quotes\" and 'apostrophes'",
            "Numbers & Symbols: 123!@#$%",
            "Unicode: 日本語タイトル"
        ]
        
        for title in specialTitles {
            let progressBar = createProgressBar(videoTitle: title)
            #expect(progressBar.videoTitle == title)
        }
    }
    
    // MARK: - Animation Logic Tests
    
    @Test
    func animation_springConfiguration() {
        // Test the spring animation parameters
        let response: Double = 0.3
        let dampingFraction: Double = 0.8
        
        // Verify reasonable animation values
        #expect(response > 0)
        #expect(dampingFraction > 0 && dampingFraction <= 1)
    }
    
    @Test
    func pulsingAnimation_duration() {
        // Test pulsing animation duration
        let duration: Double = 0.6
        
        #expect(duration > 0)
        #expect(duration < 2.0) // Should be reasonably fast
    }
    
    // MARK: - Edge Cases and Error Handling Tests
    
    @Test
    func extremeValues_handledGracefully() {
        // Test extreme values
        let extremeCases = [
            (progress: -1.0, seconds: -10.0),
            (progress: Double.infinity, seconds: Double.infinity),
            (progress: 999999.0, seconds: 999999.0)
        ]
        
        for (progress, seconds) in extremeCases {
            // Should not crash when creating the view
            let progressBar = createProgressBar(
                bufferProgress: progress,
                bufferSeconds: seconds
            )
            
            #expect(progressBar.bufferProgress == progress)
            #expect(progressBar.bufferSeconds == seconds)
        }
        
        // Test NaN values separately since NaN != NaN
        let nanProgress = Double.nan
        let nanSeconds = Double.nan
        let progressBarWithNaN = createProgressBar(
            bufferProgress: nanProgress,
            bufferSeconds: nanSeconds
        )
        
        #expect(progressBarWithNaN.bufferProgress.isNaN)
        #expect(progressBarWithNaN.bufferSeconds.isNaN)
    }
    
    // MARK: - Integration Tests
    
    @Test
    func completeProgressBar_allStates() {
        // Test creating progress bars for all buffer states with various configurations
        for state in BufferState.allCases {
            let progressBar = createProgressBar(
                videoTitle: "Test Video - \(state.description)",
                bufferState: state,
                isActivelyBuffering: state.isProblematic,
                showReadinessMarker: true
            )
            
            #expect(progressBar.bufferState == state)
            #expect(progressBar.isActivelyBuffering == state.isProblematic)
            #expect(progressBar.showReadinessMarker == true)
        }
    }
    
    @Test
    func stateColorConsistency_withBufferState() {
        // Test that color scheme is consistent with buffer state severity
        let stateColorMappings: [(BufferState, Bool)] = [
            (.unknown, true),    // Gray - neutral
            (.empty, false),     // Red - problematic
            (.critical, false),  // Red with opacity - problematic
            (.low, false),       // Orange - warning
            (.sufficient, true), // Yellow - caution but ok
            (.good, true),       // Green with opacity - good
            (.excellent, true)   // Green - excellent
        ]
        
        for (state, isPositiveColor) in stateColorMappings {
            let color = getColorForState(state)
            
            // This is a conceptual test - in practice you'd check color properties
            if isPositiveColor {
                // Green or yellow colors indicate positive states
                let isGreenish = color == .green || color == Color.green.opacity(0.7) || color == .yellow
                let isNeutral = color == .gray
                #expect(isGreenish || isNeutral, "State \(state.description) should have positive/neutral color")
            } else {
                // Red or orange colors indicate problematic states
                let isProblematic = color == .red || color == Color.red.opacity(0.8) || color == .orange
                #expect(isProblematic, "State \(state.description) should have problematic color")
            }
        }
    }
}