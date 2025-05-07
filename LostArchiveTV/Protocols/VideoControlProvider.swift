import Foundation
import AVFoundation

protocol VideoControlProvider: ObservableObject, VideoDownloadable {
    // Required video properties
    var player: AVPlayer? { get }
    var downloadViewModel: VideoDownloadViewModel { get }
    
    // Button state properties
    var isFavorite: Bool { get }
    
    // Required actions
    func toggleFavorite() 
    func restartVideo() 
    func pausePlayback() async
    func resumePlayback() async
    
    // Playback rate control
    func setTemporaryPlaybackRate(rate: Float)
    func resetPlaybackRate()
}