//
//  LoadingStateProvider.swift
//  LostArchiveTV
//
//  Created by Claude on 2025-06-29.
//

import Foundation
import Combine

/// Protocol that provides a single source of truth for loading and buffering state
@MainActor
protocol LoadingStateProvider: AnyObject {
    /// Whether content is currently loading
    var isLoading: Bool { get }
    
    /// Buffer progress from 0.0 to 1.0
    var bufferProgress: Double { get }
    
    /// Current buffer state
    var bufferState: BufferState { get }
    
    /// Publisher for loading state changes
    var isLoadingPublisher: Published<Bool>.Publisher { get }
    
    /// Publisher for buffer progress changes
    var bufferProgressPublisher: Published<Double>.Publisher { get }
    
    /// Publisher for buffer state changes
    var bufferStatePublisher: Published<BufferState>.Publisher { get }
}