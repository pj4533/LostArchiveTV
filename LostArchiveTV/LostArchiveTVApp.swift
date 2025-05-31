//
//  LostArchiveTVApp.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import SwiftUI
import OSLog
import Mixpanel

@main
struct LostArchiveTVApp: App {
    // Track app state changes
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Initialize environment service to load API keys
        let _ = EnvironmentService.shared
        Mixpanel.initialize(token: "f191a6da642536fbb49cb9cdabd662a6")
        
        // Generate and persist anonymous user ID
        let userDefaults = UserDefaults.standard
        let anonymousUserIDKey = "anonymousUserID"
        
        if let existingID = userDefaults.string(forKey: anonymousUserIDKey) {
            // Use existing ID
            Mixpanel.mainInstance().identify(distinctId: existingID)
        } else {
            // Generate new UUID for this installation
            let newID = UUID().uuidString
            userDefaults.set(newID, forKey: anonymousUserIDKey)
            Mixpanel.mainInstance().identify(distinctId: newID)
        }
        
        Mixpanel.mainInstance().track(event: "App Launch")
    }
    
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
