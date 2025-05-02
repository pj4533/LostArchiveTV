import Foundation

protocol FeedItem: Identifiable {
    var id: String { get }
    var title: String { get }
    var description: String? { get }
    var thumbnailURL: URL? { get }
    var metadata: [String: String] { get }
}