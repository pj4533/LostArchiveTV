import Foundation
import AVFoundation

protocol VideoControlProvider: ObservableObject, VideoDownloadable {
    // Required video properties
    var player: AVPlayer? { get }
    var downloadViewModel: VideoDownloadViewModel { get }
    var currentIdentifier: String? { get }
    var currentTitle: String? { get }
    var currentCollection: String? { get }

    // Button state properties
    var isFavorite: Bool { get }
    var isIdentifierSaved: Bool { get }

    // Required actions
    func toggleFavorite()
    func restartVideo()
    func pausePlayback() async
    func resumePlayback() async
    func saveIdentifier() async
    func showPresetSelection() async

    // Playback rate control
    func setTemporaryPlaybackRate(rate: Float)
    func resetPlaybackRate()
}