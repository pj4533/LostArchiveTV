//
//  BufferStateTests.swift
//  LostArchiveTVTests
//
//  Created by Claude on 6/28/25.
//

import Testing
@testable import LATV

struct BufferStateTests {
    
    // MARK: - Test state determination from seconds
    
    @Test
    func fromSeconds_withNegativeValue_returnsEmpty() {
        // Arrange
        let seconds: Double = -1.0
        
        // Act
        let state = BufferState.from(seconds: seconds)
        
        // Assert
        #expect(state == .empty)
    }
    
    @Test
    func fromSeconds_withZeroSeconds_returnsEmpty() {
        // Arrange
        let seconds: Double = 0.0
        
        // Act
        let state = BufferState.from(seconds: seconds)
        
        // Assert
        #expect(state == .empty)
    }
    
    @Test
    func fromSeconds_withVerySmallValue_returnsEmpty() {
        // Arrange
        let seconds: Double = 0.05
        
        // Act
        let state = BufferState.from(seconds: seconds)
        
        // Assert
        #expect(state == .empty)
    }
    
    @Test
    func fromSeconds_atEmptyCriticalBoundary_returnsCritical() {
        // Arrange
        let seconds: Double = 0.1
        
        // Act
        let state = BufferState.from(seconds: seconds)
        
        // Assert
        #expect(state == .critical)
    }
    
    @Test
    func fromSeconds_withCriticalRange_returnsCritical() {
        // Arrange
        let testValues: [Double] = [0.5, 1.0, 2.0, 2.9]
        
        for seconds in testValues {
            // Act
            let state = BufferState.from(seconds: seconds)
            
            // Assert
            #expect(state == .critical, "Expected critical state for \(seconds) seconds")
        }
    }
    
    @Test
    func fromSeconds_atCriticalLowBoundary_returnsLow() {
        // Arrange
        let seconds: Double = 3.0
        
        // Act
        let state = BufferState.from(seconds: seconds)
        
        // Assert
        #expect(state == .low)
    }
    
    @Test
    func fromSeconds_withLowRange_returnsLow() {
        // Arrange
        let testValues: [Double] = [3.1, 5.0, 7.5, 9.9]
        
        for seconds in testValues {
            // Act
            let state = BufferState.from(seconds: seconds)
            
            // Assert
            #expect(state == .low, "Expected low state for \(seconds) seconds")
        }
    }
    
    @Test
    func fromSeconds_atLowSufficientBoundary_returnsSufficient() {
        // Arrange
        let seconds: Double = 10.0
        
        // Act
        let state = BufferState.from(seconds: seconds)
        
        // Assert
        #expect(state == .sufficient)
    }
    
    @Test
    func fromSeconds_withSufficientRange_returnsSufficient() {
        // Arrange
        let testValues: [Double] = [10.1, 12.5, 15.0, 19.9]
        
        for seconds in testValues {
            // Act
            let state = BufferState.from(seconds: seconds)
            
            // Assert
            #expect(state == .sufficient, "Expected sufficient state for \(seconds) seconds")
        }
    }
    
    @Test
    func fromSeconds_atSufficientGoodBoundary_returnsGood() {
        // Arrange
        let seconds: Double = 20.0
        
        // Act
        let state = BufferState.from(seconds: seconds)
        
        // Assert
        #expect(state == .good)
    }
    
    @Test
    func fromSeconds_withGoodRange_returnsGood() {
        // Arrange
        let testValues: [Double] = [20.1, 22.5, 25.0, 29.9]
        
        for seconds in testValues {
            // Act
            let state = BufferState.from(seconds: seconds)
            
            // Assert
            #expect(state == .good, "Expected good state for \(seconds) seconds")
        }
    }
    
    @Test
    func fromSeconds_atGoodExcellentBoundary_returnsExcellent() {
        // Arrange
        let seconds: Double = 30.0
        
        // Act
        let state = BufferState.from(seconds: seconds)
        
        // Assert
        #expect(state == .excellent)
    }
    
    @Test
    func fromSeconds_withExcellentRange_returnsExcellent() {
        // Arrange
        let testValues: [Double] = [30.1, 50.0, 100.0, 1000.0]
        
        for seconds in testValues {
            // Act
            let state = BufferState.from(seconds: seconds)
            
            // Assert
            #expect(state == .excellent, "Expected excellent state for \(seconds) seconds")
        }
    }
    
    @Test
    func fromSeconds_withInfiniteValue_returnsExcellent() {
        // Arrange
        let seconds: Double = .infinity
        
        // Act
        let state = BufferState.from(seconds: seconds)
        
        // Assert
        #expect(state == .excellent)
    }
    
    @Test
    func fromSeconds_withNaNValue_returnsUnknown() {
        // Arrange
        let seconds: Double = .nan
        
        // Act
        let state = BufferState.from(seconds: seconds)
        
        // Assert
        #expect(state == .unknown)
    }
    
    // MARK: - Test description property
    
    @Test
    func description_forAllStates_returnsCorrectStrings() {
        // Arrange & Act & Assert
        #expect(BufferState.unknown.description == "Unknown")
        #expect(BufferState.empty.description == "Empty")
        #expect(BufferState.critical.description == "Critical")
        #expect(BufferState.low.description == "Low")
        #expect(BufferState.sufficient.description == "Sufficient")
        #expect(BufferState.good.description == "Good")
        #expect(BufferState.excellent.description == "Excellent")
    }
    
    // MARK: - Test isProblematic property
    
    @Test
    func isProblematic_forProblematicStates_returnsTrue() {
        // Arrange
        let problematicStates: [BufferState] = [.unknown, .empty, .critical]
        
        for state in problematicStates {
            // Act & Assert
            #expect(state.isProblematic, "Expected \(state.description) to be problematic")
        }
    }
    
    @Test
    func isProblematic_forNonProblematicStates_returnsFalse() {
        // Arrange
        let nonProblematicStates: [BufferState] = [.low, .sufficient, .good, .excellent]
        
        for state in nonProblematicStates {
            // Act & Assert
            #expect(!state.isProblematic, "Expected \(state.description) to not be problematic")
        }
    }
    
    // MARK: - Test isReady property
    
    @Test
    func isReady_forReadyStates_returnsTrue() {
        // Arrange
        let readyStates: [BufferState] = [.sufficient, .good, .excellent]
        
        for state in readyStates {
            // Act & Assert
            #expect(state.isReady, "Expected \(state.description) to be ready")
        }
    }
    
    @Test
    func isReady_forNotReadyStates_returnsFalse() {
        // Arrange
        let notReadyStates: [BufferState] = [.unknown, .empty, .critical, .low]
        
        for state in notReadyStates {
            // Act & Assert
            #expect(!state.isReady, "Expected \(state.description) to not be ready")
        }
    }
    
    // MARK: - Test edge cases and boundary values
    
    @Test
    func edgeCases_precisionHandling() {
        // Test very small numbers near boundaries
        
        // Just below 0.1
        let justBelowCritical = 0.09999999
        #expect(BufferState.from(seconds: justBelowCritical) == .empty)
        
        // Just above 0.1
        let justAboveCritical = 0.10000001
        #expect(BufferState.from(seconds: justAboveCritical) == .critical)
        
        // Just below 3.0
        let justBelowLow = 2.99999999
        #expect(BufferState.from(seconds: justBelowLow) == .critical)
        
        // Just above 3.0
        let justAboveLow = 3.00000001
        #expect(BufferState.from(seconds: justAboveLow) == .low)
    }
    
    @Test
    func allCases_coverageTest() {
        // Arrange
        let allCases = BufferState.allCases
        
        // Act & Assert
        #expect(allCases.count == 7)
        #expect(allCases.contains(.unknown))
        #expect(allCases.contains(.empty))
        #expect(allCases.contains(.critical))
        #expect(allCases.contains(.low))
        #expect(allCases.contains(.sufficient))
        #expect(allCases.contains(.good))
        #expect(allCases.contains(.excellent))
    }
    
    @Test
    func rawValue_accessibility() {
        // Test that raw values are accessible for debugging/logging
        #expect(BufferState.unknown.rawValue == "unknown")
        #expect(BufferState.empty.rawValue == "empty")
        #expect(BufferState.critical.rawValue == "critical")
        #expect(BufferState.low.rawValue == "low")
        #expect(BufferState.sufficient.rawValue == "sufficient")
        #expect(BufferState.good.rawValue == "good")
        #expect(BufferState.excellent.rawValue == "excellent")
    }
    
    // MARK: - Test state transitions and logic consistency
    
    @Test
    func stateTransitions_logicalConsistency() {
        // Test that as buffer seconds increase, states progress logically
        let testPoints: [(Double, BufferState)] = [
            (0, .empty),
            (0.1, .critical),
            (3, .low),
            (10, .sufficient),
            (20, .good),
            (30, .excellent)
        ]
        
        for (seconds, expectedState) in testPoints {
            let actualState = BufferState.from(seconds: seconds)
            #expect(actualState == expectedState, "At \(seconds) seconds, expected \(expectedState.description) but got \(actualState.description)")
        }
    }
    
    @Test
    func problematicAndReadyStates_mutuallyExclusive() {
        // Test that no state is both problematic and ready
        for state in BufferState.allCases {
            let isProblematic = state.isProblematic
            let isReady = state.isReady
            
            #expect(!(isProblematic && isReady), "State \(state.description) cannot be both problematic and ready")
        }
    }
}