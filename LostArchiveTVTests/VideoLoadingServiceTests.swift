//
//  VideoLoadingServiceTests.swift
//  LostArchiveTVTests
//
//  Created by Claude on 2025-07-01.
//

import Testing
import Foundation
import AVFoundation
@testable import LATV

@Suite(.serialized)
struct VideoLoadingServiceTests {
    
    // MARK: - detectContentError Tests
    
    @Test
    func detectContentError_withNilError_returnsFalse() async {
        // Arrange
        let archiveService = ArchiveService()
        let cacheManager = VideoCacheManager()
        let service = VideoLoadingService(archiveService: archiveService, cacheManager: cacheManager)
        
        // Act
        let result = await service.detectContentError(error: nil)
        
        // Assert
        #expect(result == false)
    }
    
    @Test
    func detectContentError_withArchiveContentDeleted_returnsTrue() async {
        // Arrange
        let archiveService = ArchiveService()
        let cacheManager = VideoCacheManager()
        let service = VideoLoadingService(archiveService: archiveService, cacheManager: cacheManager)
        let error = ArchiveError.contentDeleted
        
        // Act
        let result = await service.detectContentError(error: error)
        
        // Assert
        #expect(result == true)
    }
    
    @Test
    func detectContentError_withArchiveContentRestricted_returnsTrue() async {
        // Arrange
        let archiveService = ArchiveService()
        let cacheManager = VideoCacheManager()
        let service = VideoLoadingService(archiveService: archiveService, cacheManager: cacheManager)
        let error = ArchiveError.contentRestricted
        
        // Act
        let result = await service.detectContentError(error: error)
        
        // Assert
        #expect(result == true)
    }
    
    @Test
    func detectContentError_withArchiveInvalidFormat_returnsTrue() async {
        // Arrange
        let archiveService = ArchiveService()
        let cacheManager = VideoCacheManager()
        let service = VideoLoadingService(archiveService: archiveService, cacheManager: cacheManager)
        let error = ArchiveError.invalidFormat
        
        // Act
        let result = await service.detectContentError(error: error)
        
        // Assert
        #expect(result == true)
    }
    
    @Test
    func detectContentError_withArchiveNoIdentifiersFound_returnsFalse() async {
        // Arrange
        let archiveService = ArchiveService()
        let cacheManager = VideoCacheManager()
        let service = VideoLoadingService(archiveService: archiveService, cacheManager: cacheManager)
        let error = ArchiveError.noIdentifiersFound
        
        // Act
        let result = await service.detectContentError(error: error)
        
        // Assert
        #expect(result == false)
    }
    
    @Test
    func detectContentError_withArchiveMetadataDecodingFailed_returnsFalse() async {
        // Arrange
        let archiveService = ArchiveService()
        let cacheManager = VideoCacheManager()
        let service = VideoLoadingService(archiveService: archiveService, cacheManager: cacheManager)
        let error = ArchiveError.metadataDecodingFailed(identifier: "test123")
        
        // Act
        let result = await service.detectContentError(error: error)
        
        // Assert
        #expect(result == false)
    }
    
    @Test
    func detectContentError_withURLErrorFileDoesNotExist_returnsTrue() async {
        // Arrange
        let archiveService = ArchiveService()
        let cacheManager = VideoCacheManager()
        let service = VideoLoadingService(archiveService: archiveService, cacheManager: cacheManager)
        let error = URLError(.fileDoesNotExist)
        
        // Act
        let result = await service.detectContentError(error: error)
        
        // Assert
        #expect(result == true)
    }
    
    @Test
    func detectContentError_withURLErrorFileIsDirectory_returnsTrue() async {
        // Arrange
        let archiveService = ArchiveService()
        let cacheManager = VideoCacheManager()
        let service = VideoLoadingService(archiveService: archiveService, cacheManager: cacheManager)
        let error = URLError(.fileIsDirectory)
        
        // Act
        let result = await service.detectContentError(error: error)
        
        // Assert
        #expect(result == true)
    }
    
    @Test
    func detectContentError_withURLErrorNoPermissionsToReadFile_returnsTrue() async {
        // Arrange
        let archiveService = ArchiveService()
        let cacheManager = VideoCacheManager()
        let service = VideoLoadingService(archiveService: archiveService, cacheManager: cacheManager)
        let error = URLError(.noPermissionsToReadFile)
        
        // Act
        let result = await service.detectContentError(error: error)
        
        // Assert
        #expect(result == true)
    }
    
    @Test
    func detectContentError_withURLErrorNetworkConnectionLost_returnsFalse() async {
        // Arrange
        let archiveService = ArchiveService()
        let cacheManager = VideoCacheManager()
        let service = VideoLoadingService(archiveService: archiveService, cacheManager: cacheManager)
        let error = URLError(.networkConnectionLost)
        
        // Act
        let result = await service.detectContentError(error: error)
        
        // Assert
        #expect(result == false)
    }
    
    @Test
    func detectContentError_withURLErrorTimedOut_returnsFalse() async {
        // Arrange
        let archiveService = ArchiveService()
        let cacheManager = VideoCacheManager()
        let service = VideoLoadingService(archiveService: archiveService, cacheManager: cacheManager)
        let error = URLError(.timedOut)
        
        // Act
        let result = await service.detectContentError(error: error)
        
        // Assert
        #expect(result == false)
    }
    
    @Test
    func detectContentError_withNSURLErrorFileDoesNotExist_returnsTrue() async {
        // Arrange
        let archiveService = ArchiveService()
        let cacheManager = VideoCacheManager()
        let service = VideoLoadingService(archiveService: archiveService, cacheManager: cacheManager)
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorFileDoesNotExist, userInfo: nil)
        
        // Act
        let result = await service.detectContentError(error: error)
        
        // Assert
        #expect(result == true)
    }
    
    @Test
    func detectContentError_withNSURLErrorFileIsDirectory_returnsTrue() async {
        // Arrange
        let archiveService = ArchiveService()
        let cacheManager = VideoCacheManager()
        let service = VideoLoadingService(archiveService: archiveService, cacheManager: cacheManager)
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorFileIsDirectory, userInfo: nil)
        
        // Act
        let result = await service.detectContentError(error: error)
        
        // Assert
        #expect(result == true)
    }
    
    @Test
    func detectContentError_withNSURLErrorNoPermissionsToReadFile_returnsTrue() async {
        // Arrange
        let archiveService = ArchiveService()
        let cacheManager = VideoCacheManager()
        let service = VideoLoadingService(archiveService: archiveService, cacheManager: cacheManager)
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNoPermissionsToReadFile, userInfo: nil)
        
        // Act
        let result = await service.detectContentError(error: error)
        
        // Assert
        #expect(result == true)
    }
    
    @Test
    func detectContentError_withAVFoundationFileFormatNotRecognized_returnsTrue() async {
        // Arrange
        let archiveService = ArchiveService()
        let cacheManager = VideoCacheManager()
        let service = VideoLoadingService(archiveService: archiveService, cacheManager: cacheManager)
        let error = NSError(domain: AVFoundationErrorDomain, code: AVError.fileFormatNotRecognized.rawValue, userInfo: nil)
        
        // Act
        let result = await service.detectContentError(error: error)
        
        // Assert
        #expect(result == true)
    }
    
    @Test
    func detectContentError_withAVFoundationContentIsUnavailable_returnsTrue() async {
        // Arrange
        let archiveService = ArchiveService()
        let cacheManager = VideoCacheManager()
        let service = VideoLoadingService(archiveService: archiveService, cacheManager: cacheManager)
        let error = NSError(domain: AVFoundationErrorDomain, code: AVError.contentIsUnavailable.rawValue, userInfo: nil)
        
        // Act
        let result = await service.detectContentError(error: error)
        
        // Assert
        #expect(result == true)
    }
    
    @Test
    func detectContentError_withAVFoundationContentIsNotAuthorized_returnsTrue() async {
        // Arrange
        let archiveService = ArchiveService()
        let cacheManager = VideoCacheManager()
        let service = VideoLoadingService(archiveService: archiveService, cacheManager: cacheManager)
        let error = NSError(domain: AVFoundationErrorDomain, code: AVError.contentIsNotAuthorized.rawValue, userInfo: nil)
        
        // Act
        let result = await service.detectContentError(error: error)
        
        // Assert
        #expect(result == true)
    }
    
    @Test
    func detectContentError_withAVFoundationContentIsProtected_returnsTrue() async {
        // Arrange
        let archiveService = ArchiveService()
        let cacheManager = VideoCacheManager()
        let service = VideoLoadingService(archiveService: archiveService, cacheManager: cacheManager)
        let error = NSError(domain: AVFoundationErrorDomain, code: AVError.contentIsProtected.rawValue, userInfo: nil)
        
        // Act
        let result = await service.detectContentError(error: error)
        
        // Assert
        #expect(result == true)
    }
    
    @Test
    func detectContentError_withAVFoundationNoLongerPlayable_returnsTrue() async {
        // Arrange
        let archiveService = ArchiveService()
        let cacheManager = VideoCacheManager()
        let service = VideoLoadingService(archiveService: archiveService, cacheManager: cacheManager)
        let error = NSError(domain: AVFoundationErrorDomain, code: AVError.noLongerPlayable.rawValue, userInfo: nil)
        
        // Act
        let result = await service.detectContentError(error: error)
        
        // Assert
        #expect(result == true)
    }
    
    @Test
    func detectContentError_withAVFoundationDecoderTemporarilyUnavailable_returnsFalse() async {
        // Arrange
        let archiveService = ArchiveService()
        let cacheManager = VideoCacheManager()
        let service = VideoLoadingService(archiveService: archiveService, cacheManager: cacheManager)
        let error = NSError(domain: AVFoundationErrorDomain, code: AVError.decoderTemporarilyUnavailable.rawValue, userInfo: nil)
        
        // Act
        let result = await service.detectContentError(error: error)
        
        // Assert
        #expect(result == false)
    }
    
    @Test
    func detectContentError_withGenericError_returnsFalse() async {
        // Arrange
        let archiveService = ArchiveService()
        let cacheManager = VideoCacheManager()
        let service = VideoLoadingService(archiveService: archiveService, cacheManager: cacheManager)
        let error = NSError(domain: "TestDomain", code: 9999, userInfo: [NSLocalizedDescriptionKey: "Generic error"])
        
        // Act
        let result = await service.detectContentError(error: error)
        
        // Assert
        #expect(result == false)
    }
    
    // MARK: - calculateFileCount Tests
    
    @Test
    func calculateFileCount_withNoFiles_returnsZero() {
        // Arrange
        let metadata = ArchiveMetadata(
            files: [],
            metadata: nil
        )
        
        // Act
        let count = VideoLoadingService.calculateFileCount(from: metadata)
        
        // Assert
        #expect(count == 0)
    }
    
    @Test
    func calculateFileCount_withMultipleMP4Files_returnsUniqueCount() {
        // Arrange
        let files = [
            ArchiveFile(name: "video1.mp4", format: "h.264 IA", size: "1000", length: "60"),
            ArchiveFile(name: "video2.mp4", format: "h.264 IA", size: "2000", length: "120"),
            ArchiveFile(name: "video1.mp4", format: "h.264 IA", size: "1000", length: "60") // Duplicate
        ]
        
        let metadata = ArchiveMetadata(
            files: files,
            metadata: nil
        )
        
        // Act
        let count = VideoLoadingService.calculateFileCount(from: metadata)
        
        // Assert
        #expect(count == 2) // Two unique base names
    }
    
    @Test
    func calculateFileCount_withVariousVideoFormats_countsAllFormats() {
        // Arrange
        let files = [
            ArchiveFile(name: "video1.mp4", format: "h.264 IA", size: "1000", length: "60"),
            ArchiveFile(name: "video2.mp4", format: "h.264", size: "2000", length: "120"),
            ArchiveFile(name: "video3.mp4", format: "MPEG4", size: "3000", length: "180"),
            ArchiveFile(name: "document.pdf", format: "PDF", size: "500", length: nil) // Non-video
        ]
        
        let metadata = ArchiveMetadata(
            files: files,
            metadata: nil
        )
        
        // Act
        let count = VideoLoadingService.calculateFileCount(from: metadata)
        
        // Assert
        #expect(count == 3) // Three video files, PDF ignored
    }
}