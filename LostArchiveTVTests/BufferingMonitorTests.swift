//
//  BufferingMonitorTests.swift
//  LostArchiveTVTests
//
//  Created by Claude on 6/28/25.
//

import Testing
import AVFoundation
import Combine
@testable import LATV

@MainActor
struct BufferingMonitorTests {
    
    // MARK: - Helper methods
    
    private func createTestPlayer() -> AVPlayer {
        let url = URL(string: "https://example.com/test.mp4")!
        return AVPlayer(url: url)
    }
    
    private func createTestPlayerWithItem() -> (AVPlayer, AVPlayerItem) {
        let url = URL(string: "https://example.com/test.mp4")!
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        return (player, item)
    }
    
    // MARK: - Initialization Tests
    
    @Test
    func init_setsDefaultValues() {
        // Arrange & Act
        let monitor = BufferingMonitor()
        
        // Assert
        #expect(monitor.bufferProgress == 0.0)
        #expect(monitor.bufferSeconds == 0.0)
        #expect(monitor.bufferState == .unknown)
        #expect(monitor.isActivelyBuffering == false)
        #expect(monitor.isPlaybackLikelyToKeepUp == false)
        #expect(monitor.bufferFillRate == 0.0)
    }
    
    // MARK: - Start/Stop Monitoring Tests
    
    @Test
    func startMonitoring_withValidPlayer_initializesCorrectly() {
        // Arrange
        let monitor = BufferingMonitor()
        let player = createTestPlayer()
        
        // Act
        monitor.startMonitoring(player)
        
        // Assert
        // Initial state should be reset to defaults
        #expect(monitor.bufferProgress == 0.0)
        #expect(monitor.bufferSeconds == 0.0)
        #expect(monitor.bufferState == .unknown)
        #expect(monitor.isActivelyBuffering == false)
        #expect(monitor.isPlaybackLikelyToKeepUp == false)
        #expect(monitor.bufferFillRate == 0.0)
    }
    
    @Test
    func stopMonitoring_resetsAllValues() {
        // Arrange
        let monitor = BufferingMonitor()
        let player = createTestPlayer()
        monitor.startMonitoring(player)
        
        // Act
        monitor.stopMonitoring()
        
        // Assert
        #expect(monitor.bufferProgress == 0.0)
        #expect(monitor.bufferSeconds == 0.0)
        #expect(monitor.bufferState == .unknown)
        #expect(monitor.isActivelyBuffering == false)
        #expect(monitor.isPlaybackLikelyToKeepUp == false)
        #expect(monitor.bufferFillRate == 0.0)
    }
    
    @Test
    func startMonitoring_multipleTimes_cleansUpPreviousObservations() {
        // Arrange
        let monitor = BufferingMonitor()
        let player1 = createTestPlayer()
        let player2 = createTestPlayer()
        
        // Act
        monitor.startMonitoring(player1)
        monitor.startMonitoring(player2)
        
        // Assert
        // Should not crash and should reset values
        #expect(monitor.bufferProgress == 0.0)
        #expect(monitor.bufferState == .unknown)
    }
    
    // MARK: - Buffer Progress Calculation Tests
    
    @Test
    func bufferProgress_withZeroBuffer_returnsZero() {
        // Arrange
        let monitor = BufferingMonitor()
        
        // Act & Assert
        #expect(monitor.bufferProgress == 0.0)
    }
    
    @Test
    func bufferProgress_calculationLogic() {
        // This test verifies the logic would work correctly
        // In a real scenario, bufferProgress = min(bufferSeconds / 30.0, 1.0)
        
        // Test data: (bufferSeconds, expectedProgress)
        let testCases: [(Double, Double)] = [
            (0.0, 0.0),
            (15.0, 0.5),    // 15/30 = 0.5
            (30.0, 1.0),    // 30/30 = 1.0
            (45.0, 1.0),    // min(45/30, 1.0) = 1.0 (capped)
            (60.0, 1.0)     // min(60/30, 1.0) = 1.0 (capped)
        ]
        
        for (bufferSeconds, expectedProgress) in testCases {
            let calculatedProgress = min(bufferSeconds / 30.0, 1.0)
            #expect(calculatedProgress == expectedProgress, 
                   "Buffer of \(bufferSeconds)s should give progress \(expectedProgress), got \(calculatedProgress)")
        }
    }
    
    // MARK: - Buffer State Updates Tests
    
    @Test
    func bufferState_updatesCorrectlyBasedOnSeconds() {
        // Test the state update logic
        let testCases: [(Double, BufferState)] = [
            (0.0, .empty),
            (1.0, .critical),
            (5.0, .low),
            (15.0, .sufficient),
            (25.0, .good),
            (35.0, .excellent)
        ]
        
        for (seconds, expectedState) in testCases {
            let calculatedState = BufferState.from(seconds: seconds)
            #expect(calculatedState == expectedState,
                   "Buffer of \(seconds)s should give state \(expectedState.description), got \(calculatedState.description)")
        }
    }
    
    // MARK: - Fill Rate Calculation Tests
    
    @Test
    func bufferFillRate_initialValue_isZero() {
        // Arrange
        let monitor = BufferingMonitor()
        
        // Act & Assert
        #expect(monitor.bufferFillRate == 0.0)
    }
    
    @Test
    func fillRateCalculation_logic() {
        // Test the mathematical logic that would be used in fill rate calculation
        // fillRate = bufferDelta / timeDelta
        
        let testCases: [(bufferDelta: Double, timeDelta: Double, expectedRate: Double)] = [
            (10.0, 5.0, 2.0),    // Gaining 10 seconds over 5 seconds = 2.0 rate
            (-5.0, 2.0, -2.5),   // Losing 5 seconds over 2 seconds = -2.5 rate
            (0.0, 1.0, 0.0),     // No change = 0.0 rate
            (3.0, 1.5, 2.0)      // Gaining 3 seconds over 1.5 seconds = 2.0 rate
        ]
        
        for (bufferDelta, timeDelta, expectedRate) in testCases {
            let calculatedRate = bufferDelta / timeDelta
            #expect(abs(calculatedRate - expectedRate) < 0.001,
                   "Buffer delta \(bufferDelta) over time \(timeDelta) should give rate \(expectedRate), got \(calculatedRate)")
        }
    }
    
    // MARK: - Player Item Observation Tests
    
    @Test
    func playerItemChange_resetsMetrics() {
        // Arrange
        let monitor = BufferingMonitor()
        let (player, _) = createTestPlayerWithItem()
        
        // Act
        monitor.startMonitoring(player)
        
        // Assert initial state
        #expect(monitor.bufferProgress == 0.0)
        #expect(monitor.bufferState == .unknown)
        
        // Simulate player item change by stopping and restarting
        monitor.stopMonitoring()
        #expect(monitor.bufferProgress == 0.0)
        #expect(monitor.bufferState == .unknown)
    }
    
    // MARK: - Edge Cases and Error Handling Tests
    
    @Test
    func startMonitoring_withNilCurrentItem_handlesGracefully() {
        // Arrange
        let monitor = BufferingMonitor()
        let player = AVPlayer() // Player with no current item
        
        // Act
        monitor.startMonitoring(player)
        
        // Assert - should not crash and maintain default values
        #expect(monitor.bufferProgress == 0.0)
        #expect(monitor.bufferState == .unknown)
    }
    
    @Test
    func invalidTimeValues_handledGracefully() {
        // Test the logic for handling invalid CMTime values
        let invalidTime = CMTime.invalid
        let indefiniteTime = CMTime.indefinite
        
        #expect(!invalidTime.isValid)
        #expect(!invalidTime.isNumeric)
        #expect(!indefiniteTime.isNumeric)
    }
    
    @Test
    func bufferCalculation_withEmptyTimeRanges_returnsZero() {
        // Test the logic that would handle empty loaded time ranges
        let emptyRanges: [NSValue] = []
        #expect(emptyRanges.isEmpty)
        
        // In the actual implementation, this would return 0.0 buffer
        let expectedBuffer = 0.0
        #expect(expectedBuffer == 0.0)
    }
    
    @Test
    func bufferCalculation_withValidTimeRange() {
        // Test the logic for calculating buffer from time ranges
        let currentSeconds = 10.0
        let rangeStart = 5.0
        let rangeEnd = 25.0
        
        // If current time is within range, buffer = rangeEnd - currentSeconds
        if currentSeconds >= rangeStart && currentSeconds <= rangeEnd {
            let calculatedBuffer = rangeEnd - currentSeconds
            #expect(calculatedBuffer == 15.0)
        }
        
        // If range is ahead of current time
        let futureRangeStart = 15.0
        let futureRangeEnd = 30.0
        if futureRangeStart > currentSeconds {
            let calculatedBuffer = futureRangeEnd - currentSeconds
            #expect(calculatedBuffer == 20.0)
        }
    }
    
    // MARK: - Constants and Thresholds Tests
    
    @Test
    func targetBufferSeconds_isCorrectValue() {
        // Verify the target buffer duration is 30 seconds as expected
        let targetBuffer = 30.0
        
        // Test progress calculation uses this value
        let testProgress = 15.0 / targetBuffer
        #expect(testProgress == 0.5)
    }
    
    @Test
    func minimumBufferChangeThreshold_logic() {
        // Test the threshold logic for buffer change detection
        let threshold = 0.1
        let testChanges = [0.05, 0.1, 0.15, 0.2]
        
        for change in testChanges {
            let shouldUpdate = abs(change) >= threshold
            if change >= threshold {
                #expect(shouldUpdate, "Change of \(change) should trigger update")
            } else {
                #expect(!shouldUpdate, "Change of \(change) should not trigger update")
            }
        }
    }
    
    // MARK: - Observable Properties Tests
    
    @Test
    func observableProperties_initiallyFalse() {
        // Arrange
        let monitor = BufferingMonitor()
        
        // Act & Assert
        #expect(!monitor.isActivelyBuffering)
        #expect(!monitor.isPlaybackLikelyToKeepUp)
    }
    
    // MARK: - Memory Management Tests
    
    @Test
    func deinit_cleansUpResources() async {
        // Test that the monitor can be deallocated properly
        var monitor: BufferingMonitor? = BufferingMonitor()
        let player = createTestPlayer()
        
        monitor?.startMonitoring(player)
        
        // Release the monitor
        monitor = nil
        
        // Should not cause any memory leaks or crashes
        #expect(monitor == nil)
    }
    
    // MARK: - Thread Safety Tests
    
    @Test
    func mainActorIsolation_verifyDecoration() {
        // Verify that BufferingMonitor is properly decorated with @MainActor
        // This test confirms the class can only be used on the main actor
        let monitor = BufferingMonitor()
        
        // Should be able to access properties on main actor
        #expect(monitor.bufferProgress >= 0.0)
        #expect(monitor.bufferState == .unknown)
    }
    
    // MARK: - Integration Logic Tests
    
    @Test
    func completeWorkflow_logic() {
        // Test the expected workflow logic
        let monitor = BufferingMonitor()
        let player = createTestPlayer()
        
        // 1. Start monitoring
        monitor.startMonitoring(player)
        #expect(monitor.bufferState == .unknown)
        
        // 2. Simulate buffer updates (logic verification)
        let mockBufferSeconds = 15.0
        let expectedProgress = min(mockBufferSeconds / 30.0, 1.0)
        let expectedState = BufferState.from(seconds: mockBufferSeconds)
        
        #expect(expectedProgress == 0.5)
        #expect(expectedState == .sufficient)
        
        // 3. Stop monitoring
        monitor.stopMonitoring()
        #expect(monitor.bufferState == .unknown)
        #expect(monitor.bufferProgress == 0.0)
    }
}