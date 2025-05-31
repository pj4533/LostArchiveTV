//
//  NotificationOverlayView.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 5/31/25.
//

import SwiftUI

struct NotificationOverlayView: View {
    @ObservedObject var viewState: PlayerViewState
    
    var body: some View {
        if viewState.showSavedNotification {
            VStack {
                SavedIdentifierOverlay(
                    title: viewState.savedIdentifierTitle,
                    presetName: viewState.savedPresetName,
                    isVisible: $viewState.showSavedNotification,
                    isDuplicate: viewState.isDuplicate
                )
                .padding(.top, 50)

                Spacer()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .zIndex(110) // Ensure it's above all other content
        }
    }
}