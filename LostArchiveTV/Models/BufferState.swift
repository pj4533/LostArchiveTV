//
//  BufferState.swift
//  LostArchiveTV
//
//  Created by Claude on 2025-06-28.
//

import Foundation

/// Represents the current buffering state based on available buffer duration
enum BufferState: String, CaseIterable {
    /// Buffer state is not yet determined
    case unknown
    
    /// Buffer is empty or nearly empty (< 0.1 seconds)
    case empty
    
    /// Buffer is critically low (< 3 seconds)
    case critical
    
    /// Buffer is low but functional (3-10 seconds)
    case low
    
    /// Buffer is sufficient for smooth playback (10-20 seconds)
    case sufficient
    
    /// Buffer is in good condition (20-30 seconds)
    case good
    
    /// Buffer is excellent with plenty of headroom (> 30 seconds)
    case excellent
    
    /// Determines the buffer state based on the number of seconds buffered
    /// - Parameter seconds: The number of seconds currently buffered
    /// - Returns: The appropriate BufferState
    static func from(seconds: Double) -> BufferState {
        switch seconds {
        case ..<0.1:
            return .empty
        case 0.1..<3:
            return .critical
        case 3..<10:
            return .low
        case 10..<20:
            return .sufficient
        case 20..<30:
            return .good
        case 30...:
            return .excellent
        default:
            return .unknown
        }
    }
    
    /// A human-readable description of the buffer state
    var description: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .empty:
            return "Empty"
        case .critical:
            return "Critical"
        case .low:
            return "Low"
        case .sufficient:
            return "Sufficient"
        case .good:
            return "Good"
        case .excellent:
            return "Excellent"
        }
    }
    
    /// Indicates whether the buffer state represents a problematic condition
    var isProblematic: Bool {
        switch self {
        case .unknown, .empty, .critical:
            return true
        case .low, .sufficient, .good, .excellent:
            return false
        }
    }
    
    /// Indicates whether the buffer state represents a ready-for-playback condition
    var isReady: Bool {
        switch self {
        case .unknown, .empty, .critical, .low:
            return false
        case .sufficient, .good, .excellent:
            return true
        }
    }
}