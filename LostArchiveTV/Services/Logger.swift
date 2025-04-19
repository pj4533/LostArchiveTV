import Foundation
import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier!
    
    static let general = Logger(subsystem: subsystem, category: "general")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let videoPlayback = Logger(subsystem: subsystem, category: "videoPlayback")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let dataModel = Logger(subsystem: subsystem, category: "dataModel")
}