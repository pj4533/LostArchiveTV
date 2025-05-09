//
//  LoggerExtension.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import Foundation
import OSLog

// MARK: - Loggers
extension Logger {
    static let videoPlayback = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "videoPlayback")
    static let network = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "network")
    static let metadata = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "metadata")
    static let caching = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "caching")
    static let files = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "files")
}