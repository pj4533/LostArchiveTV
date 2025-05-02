import Foundation

protocol VideoDownloadable {
    // Required properties
    var currentIdentifier: String? { get }
    
    // Optional callbacks
    func onDownloadStart()
    func onDownloadComplete(success: Bool, error: Error?)
}