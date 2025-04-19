//
//  ArchiveServiceTests.swift
//  LostArchiveTVTests
//
//  Created by Claude on 4/19/25.
//

import Testing
@testable import LostArchiveTV

struct ArchiveServiceTests {
    
    @Test
    func findPlayableFiles_returnsMP4Files() async throws {
        // Arrange
        let archiveService = ArchiveService()
        let metadata = ArchiveMetadata(
            files: [
                ArchiveFile(name: "file1.mp4", format: "MPEG4", size: "1000", length: "120"),
                ArchiveFile(name: "file2.mp3", format: "MP3", size: "500", length: "60"),
                ArchiveFile(name: "file3.jpg", format: "JPEG", size: "300", length: nil),
                ArchiveFile(name: "file4.mp4", format: "h264", size: "2000", length: "180")
            ],
            metadata: nil
        )
        
        // Act
        let mp4Files = await archiveService.findPlayableFiles(in: metadata)
        
        // Assert
        #expect(mp4Files.count == 2)
        #expect(mp4Files[0].name == "file1.mp4")
        #expect(mp4Files[1].name == "file4.mp4")
    }
    
    @Test
    func getRandomIdentifier_returnsIdentifier() async {
        // Arrange
        let archiveService = ArchiveService()
        let identifiers = ["id1", "id2", "id3"]
        
        // Act
        let randomId = await archiveService.getRandomIdentifier(from: identifiers)
        
        // Assert
        #expect(randomId != nil)
        #expect(identifiers.contains(randomId!))
    }
    
    @Test
    func getRandomIdentifier_withEmptyArray_returnsNil() async {
        // Arrange
        let archiveService = ArchiveService()
        let identifiers: [String] = []
        
        // Act
        let randomId = await archiveService.getRandomIdentifier(from: identifiers)
        
        // Assert
        #expect(randomId == nil)
    }
    
    @Test
    func getFileDownloadURL_returnsValidURL() async {
        // Arrange
        let archiveService = ArchiveService()
        let identifier = "test123"
        let file = ArchiveFile(name: "video.mp4", format: "MPEG4", size: "1000", length: "120")
        
        // Act
        let url = await archiveService.getFileDownloadURL(for: file, identifier: identifier)
        
        // Assert
        #expect(url != nil)
        #expect(url?.absoluteString == "https://archive.org/download/test123/video.mp4")
    }
    
    @Test(arguments: [
        (file: ArchiveFile(name: "video.mp4", format: "MPEG4", size: "1000", length: "120"), expected: 120.0),
        (file: ArchiveFile(name: "video.mp4", format: "MPEG4", size: "1000", length: "01:30:00"), expected: 5400.0),
        (file: ArchiveFile(name: "video.mp4", format: "MPEG4", size: "1000", length: nil), expected: 1800.0),
        (file: ArchiveFile(name: "video.mp4", format: "MPEG4", size: "1000", length: "invalid"), expected: 1800.0)
    ])
    func estimateDuration_correctlyParsesDuration(file: ArchiveFile, expected: Double) async {
        // Arrange
        let archiveService = ArchiveService()
        
        // Act
        let duration = await archiveService.estimateDuration(fromFile: file)
        
        // Assert
        #expect(duration == expected)
    }
}