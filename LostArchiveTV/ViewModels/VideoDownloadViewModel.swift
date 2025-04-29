import Foundation
import OSLog
import Photos

/// Protocol for ViewModels that support video downloading
protocol VideoDownloadable {
    // Required properties
    var currentIdentifier: String? { get }
    
    // Optional callbacks
    func onDownloadStart()
    func onDownloadComplete(success: Bool, error: Error?)
}

/// Extension to provide default implementations for optional callbacks
extension VideoDownloadable {
    func onDownloadStart() {}
    func onDownloadComplete(success: Bool, error: Error?) {}
}

/// ViewModel extension to manage video downloads
@MainActor
class VideoDownloadViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isDownloading = false
    @Published var downloadProgress: Float = 0
    @Published var saveError: String? = nil
    @Published var showSaveSuccessAlert = false
    
    // Service for downloading videos
    private let downloadService = VideoDownloadService()
    
    // MARK: - Download functionality
    
    /// Downloads a video for the given identifier
    /// - Parameter provider: The ViewModel implementing VideoDownloadable protocol
    func downloadVideo(from provider: VideoDownloadable) {
        guard let identifier = provider.currentIdentifier else {
            saveError = "Video information not available"
            return
        }
        
        // Notify provider that download is starting
        provider.onDownloadStart()
        
        // Reset state
        isDownloading = true
        downloadProgress = 0
        
        // Start download
        downloadService.downloadVideo(
            identifier: identifier,
            progressHandler: { progress in
                self.downloadProgress = progress
            },
            completionHandler: { result in
                self.isDownloading = false
                
                switch result {
                case .success:
                    self.showSaveSuccessAlert = true
                    provider.onDownloadComplete(success: true, error: nil)
                case .failure(let error):
                    self.saveError = "Failed to save video: \(error.localizedDescription)"
                    provider.onDownloadComplete(success: false, error: error)
                }
            }
        )
    }
}