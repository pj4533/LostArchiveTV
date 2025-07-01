//
//  VideoPlaybackManagerErrorTests.swift
//  LostArchiveTVTests
//
//  Created by Claude on 2025-07-01.
//

import Testing
import Foundation
import AVFoundation
@testable import LATV

@MainActor
@Suite(.serialized)
struct VideoPlaybackManagerErrorTests {
    
    // MARK: - isUnrecoverableContentError Tests
    
    @Test
    func isUnrecoverableContentError_withAVErrorContentIsNotAuthorized_returnsTrue() async {
        // Arrange
        let manager = VideoPlaybackManager()
        let error = AVError(.contentIsNotAuthorized)
        
        // Act
        let result = manager.isUnrecoverableContentError(error)
        
        // Assert
        #expect(result == true)
    }
    
    @Test
    func isUnrecoverableContentError_withAVErrorContentIsProtected_returnsTrue() async {
        // Arrange
        let manager = VideoPlaybackManager()
        let error = AVError(.contentIsProtected)
        
        // Act
        let result = manager.isUnrecoverableContentError(error)
        
        // Assert
        #expect(result == true)
    }
    
    @Test
    func isUnrecoverableContentError_withAVErrorFileFormatNotRecognized_returnsTrue() async {
        // Arrange
        let manager = VideoPlaybackManager()
        let error = AVError(.fileFormatNotRecognized)
        
        // Act
        let result = manager.isUnrecoverableContentError(error)
        
        // Assert
        #expect(result == true)
    }
    
    @Test
    func isUnrecoverableContentError_withAVErrorFailedToParse_returnsTrue() async {
        // Arrange
        let manager = VideoPlaybackManager()
        let error = AVError(.failedToParse)
        
        // Act
        let result = manager.isUnrecoverableContentError(error)
        
        // Assert
        #expect(result == true)
    }
    
    @Test
    func isUnrecoverableContentError_withAVErrorNoLongerPlayable_returnsTrue() async {
        // Arrange
        let manager = VideoPlaybackManager()
        let error = AVError(.noLongerPlayable)
        
        // Act
        let result = manager.isUnrecoverableContentError(error)
        
        // Assert
        #expect(result == true)
    }
    
    @Test
    func isUnrecoverableContentError_withAVErrorIncompatibleAsset_returnsTrue() async {
        // Arrange
        let manager = VideoPlaybackManager()
        let error = AVError(.incompatibleAsset)
        
        // Act
        let result = manager.isUnrecoverableContentError(error)
        
        // Assert
        #expect(result == true)
    }
    
    @Test
    func isUnrecoverableContentError_withAVErrorOperationNotSupportedForAsset_returnsTrue() async {
        // Arrange
        let manager = VideoPlaybackManager()
        let error = AVError(.operationNotSupportedForAsset)
        
        // Act
        let result = manager.isUnrecoverableContentError(error)
        
        // Assert
        #expect(result == true)
    }
    
    @Test
    func isUnrecoverableContentError_withAVErrorDecoderTemporarilyUnavailable_returnsFalse() async {
        // Arrange
        let manager = VideoPlaybackManager()
        let error = AVError(.decoderTemporarilyUnavailable)
        
        // Act
        let result = manager.isUnrecoverableContentError(error)
        
        // Assert
        #expect(result == false)
    }
    
    @Test
    func isUnrecoverableContentError_withAVErrorDeviceIsNotAvailableInBackground_returnsFalse() async {
        // Arrange
        let manager = VideoPlaybackManager()
        let error = AVError(.deviceIsNotAvailableInBackground)
        
        // Act
        let result = manager.isUnrecoverableContentError(error)
        
        // Assert
        #expect(result == false)
    }
    
    @Test
    func isUnrecoverableContentError_withURLErrorFileDoesNotExist_returnsTrue() async {
        // Arrange
        let manager = VideoPlaybackManager()
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorFileDoesNotExist, userInfo: nil)
        
        // Act
        let result = manager.isUnrecoverableContentError(error)
        
        // Assert
        #expect(result == true)
    }
    
    @Test
    func isUnrecoverableContentError_withURLErrorNoPermissionsToReadFile_returnsTrue() async {
        // Arrange
        let manager = VideoPlaybackManager()
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNoPermissionsToReadFile, userInfo: nil)
        
        // Act
        let result = manager.isUnrecoverableContentError(error)
        
        // Assert
        #expect(result == true)
    }
    
    @Test
    func isUnrecoverableContentError_withURLErrorDataNotAllowed_returnsTrue() async {
        // Arrange
        let manager = VideoPlaybackManager()
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorDataNotAllowed, userInfo: nil)
        
        // Act
        let result = manager.isUnrecoverableContentError(error)
        
        // Assert
        #expect(result == true)
    }
    
    @Test
    func isUnrecoverableContentError_withURLErrorNetworkConnectionLost_returnsFalse() async {
        // Arrange
        let manager = VideoPlaybackManager()
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost, userInfo: nil)
        
        // Act
        let result = manager.isUnrecoverableContentError(error)
        
        // Assert
        #expect(result == false)
    }
    
    @Test
    func isUnrecoverableContentError_withURLErrorTimedOut_returnsFalse() async {
        // Arrange
        let manager = VideoPlaybackManager()
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: nil)
        
        // Act
        let result = manager.isUnrecoverableContentError(error)
        
        // Assert
        #expect(result == false)
    }
    
    @Test
    func isUnrecoverableContentError_withErrorDescriptionContainingFormatNotSupported_returnsTrue() async {
        // Arrange
        let manager = VideoPlaybackManager()
        let error = NSError(domain: "TestDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "The format is not supported for this video"])
        
        // Act
        let result = manager.isUnrecoverableContentError(error)
        
        // Assert
        #expect(result == true)
    }
    
    @Test
    func isUnrecoverableContentError_withErrorDescriptionContainingFileTypeNotSupported_returnsTrue() async {
        // Arrange
        let manager = VideoPlaybackManager()
        let error = NSError(domain: "TestDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "File type is not supported"])
        
        // Act
        let result = manager.isUnrecoverableContentError(error)
        
        // Assert
        #expect(result == true)
    }
    
    @Test
    func isUnrecoverableContentError_withErrorDescriptionContainingCouldNotDecode_returnsTrue() async {
        // Arrange
        let manager = VideoPlaybackManager()
        let error = NSError(domain: "TestDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not decode the video file"])
        
        // Act
        let result = manager.isUnrecoverableContentError(error)
        
        // Assert
        #expect(result == true)
    }
    
    @Test
    func isUnrecoverableContentError_withErrorDescriptionContainingCannotDecode_returnsTrue() async {
        // Arrange
        let manager = VideoPlaybackManager()
        let error = NSError(domain: "TestDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot decode video stream"])
        
        // Act
        let result = manager.isUnrecoverableContentError(error)
        
        // Assert
        #expect(result == true)
    }
    
    @Test
    func isUnrecoverableContentError_withErrorDescriptionContainingNotCompatible_returnsTrue() async {
        // Arrange
        let manager = VideoPlaybackManager()
        let error = NSError(domain: "TestDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Video format not compatible with player"])
        
        // Act
        let result = manager.isUnrecoverableContentError(error)
        
        // Assert
        #expect(result == true)
    }
    
    @Test
    func isUnrecoverableContentError_withErrorDescriptionContainingInvalid_returnsTrue() async {
        // Arrange
        let manager = VideoPlaybackManager()
        let error = NSError(domain: "TestDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid video file"])
        
        // Act
        let result = manager.isUnrecoverableContentError(error)
        
        // Assert
        #expect(result == true)
    }
    
    @Test
    func isUnrecoverableContentError_withErrorDescriptionContainingCorrupted_returnsTrue() async {
        // Arrange
        let manager = VideoPlaybackManager()
        let error = NSError(domain: "TestDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "The file appears to be corrupted"])
        
        // Act
        let result = manager.isUnrecoverableContentError(error)
        
        // Assert
        #expect(result == true)
    }
    
    @Test
    func isUnrecoverableContentError_withErrorDescriptionContainingDamaged_returnsTrue() async {
        // Arrange
        let manager = VideoPlaybackManager()
        let error = NSError(domain: "TestDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Video file is damaged"])
        
        // Act
        let result = manager.isUnrecoverableContentError(error)
        
        // Assert
        #expect(result == true)
    }
    
    @Test
    func isUnrecoverableContentError_withGenericError_returnsFalse() async {
        // Arrange
        let manager = VideoPlaybackManager()
        let error = NSError(domain: "TestDomain", code: 9999, userInfo: [NSLocalizedDescriptionKey: "A temporary network issue occurred"])
        
        // Act
        let result = manager.isUnrecoverableContentError(error)
        
        // Assert
        #expect(result == false)
    }
    
    // MARK: - handleContentFailureSilently Tests
    
    @Test
    func handleContentFailureSilently_postsNotification() async {
        // Arrange
        let manager = VideoPlaybackManager()
        let error = AVError(.fileFormatNotRecognized)
        var notificationReceived = false
        var receivedError: Error?
        
        let observer = NotificationCenter.default.addObserver(
            forName: .playerEncounteredUnrecoverableError,
            object: manager,
            queue: .main
        ) { notification in
            notificationReceived = true
            receivedError = notification.userInfo?["error"] as? Error
        }
        
        // Act
        manager.handleContentFailureSilently(error: error)
        
        // Wait a bit for notification to be posted
        try? await Task.sleep(for: .milliseconds(100))
        
        // Assert
        #expect(notificationReceived == true)
        #expect(receivedError != nil)
        
        // Cleanup
        NotificationCenter.default.removeObserver(observer)
    }
}