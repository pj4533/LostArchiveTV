//
//  LostArchiveTVApp.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import SwiftUI
import OSLog

@main
struct LostArchiveTVApp: App {
    // Track app state changes
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                Logger.network.info("App became active")
            case .inactive:
                Logger.network.info("App became inactive")
            case .background:
                // Cancel all network tasks when app moves to background
                Logger.network.info("App moved to background - cancelling all URLSession tasks")
                cancelAllNetworkTasks()
            @unknown default:
                Logger.network.info("Unknown scene phase change")
            }
        }
    }
    
    // Helper function to cancel all network tasks
    private func cancelAllNetworkTasks() {
        // Cancel all tasks in the shared session
        URLSession.shared.getAllTasks { tasks in
            for task in tasks {
                task.cancel()
                Logger.network.debug("Cancelled URLSession task: \(task)")
            }
            Logger.network.info("Cancelled \(tasks.count) shared URLSession tasks")
        }
    }
}
