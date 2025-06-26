//
//  PlayerViewState.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 5/31/25.
//

import SwiftUI
import Combine

// Helper class to manage state for the SwipeablePlayerView
class PlayerViewState: ObservableObject {
    @Published var trimStep: TrimWorkflowStep = .none
    @Published var showSavedNotification = false
    @Published var savedIdentifierTitle = ""
    @Published var savedPresetName: String? = nil
    @Published var isDuplicate = false
    
    private var trimCancellable: AnyCancellable?
    private var notificationToken: NSObjectProtocol?

    enum TrimWorkflowStep {
        case none        // No trim action in progress
        case downloading // Downloading video for trimming
        case trimming    // Showing trim interface
    }

    func setupTrimObserver(handler: @escaping () -> Void) {
        // Cancel existing subscription if it exists
        removeObservers()

        // Subscribe to the publisher
        trimCancellable = VideoEditingService.startVideoTrimmingPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard self != nil else { return }
                handler()
            }
    }
    
    func showSavedConfirmation(title: String, presetName: String? = nil, isDuplicate: Bool = false) {
        self.savedIdentifierTitle = title
        self.savedPresetName = presetName
        self.isDuplicate = isDuplicate
        
        withAnimation {
            self.showSavedNotification = true
        }
    }

    func setupNotificationObserver() {
        // Remove existing observer if it exists
        if let token = notificationToken {
            NotificationCenter.default.removeObserver(token)
            self.notificationToken = nil
        }
        
        // Create a new observer for identifier notifications
        notificationToken = NotificationCenter.default.addObserver(
            forName: Notification.Name("ShowIdentifierNotification"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            
            // Extract information from notification
            if let userInfo = notification.userInfo,
               let title = userInfo["title"] as? String,
               let presetName = userInfo["presetName"] as? String?,
               let isDuplicate = userInfo["isDuplicate"] as? Bool {
                
                // Show the notification
                self.showSavedConfirmation(
                    title: title,
                    presetName: presetName,
                    isDuplicate: isDuplicate
                )
            }
        }
    }
    
    func removeObservers() {
        trimCancellable?.cancel()
        trimCancellable = nil
        
        if let token = notificationToken {
            NotificationCenter.default.removeObserver(token)
            self.notificationToken = nil
        }
    }

    deinit {
        removeObservers()
    }
}