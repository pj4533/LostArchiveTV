//
//  SearchVideoLayerContent.swift
//  LostArchiveTV
//
//  Created by Claude on 4/26/25.
//

import SwiftUI
import AVKit
import UIKit

// Component for search video content layer
struct SearchVideoLayerContent: View {
    let player: AVPlayer
    @ObservedObject var viewModel: SearchViewModel
    var isPresented: Binding<Bool>?
    
    var body: some View {
        // Use the same layout as the main player and favorites
        ZStack {
            VStack(spacing: 0) {
                // Add spacing at top to start below the gear icon
                Spacer().frame(height: 70)
                
                // Actual player using maximum available width
                VideoPlayer(player: player)
                    .aspectRatio(contentMode: .fit)
                
                // Reserve space for the timeline controls to appear here
                Spacer()
                    .frame(height: 110)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                
                // Additional spacer to ensure separation from video info overlay
                Spacer().frame(height: 100)
            }
            
            // Create a VideoInfoOverlay-like stack with button panel
            ZStack {
                // Bottom info panel
                if let result = viewModel.currentResult {
                    BottomInfoPanel(
                        title: result.title,
                        collection: result.identifier.collection,
                        description: result.description,
                        identifier: result.identifier.identifier,
                        filename: viewModel.currentFilename,
                        currentTime: player.currentItem != nil ? player.currentTime().seconds : nil,
                        duration: viewModel.videoDuration,
                        totalFiles: viewModel.totalFiles,
                        currentBufferingMonitor: viewModel.currentBufferingMonitor,
                        nextBufferingMonitor: viewModel.nextBufferingMonitor,
                        nextVideoTitle: viewModel.nextVideoTitle
                    )
                    .id("\(viewModel.totalFiles)-\(Date())") // Force refresh periodically and when totalFiles changes
                }
                
                // Add custom back button for modal presentation
                if let isPresented = self.isPresented {
                    VStack {
                        HStack {
                            Button(action: {
                                // Stop playback before dismissing
                                Task {
                                    await viewModel.pausePlayback()
                                    // Set isPresented to false first, then set player to nil after a short delay
                                    isPresented.wrappedValue = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        viewModel.player = nil
                                    }
                                }
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                            }
                            .padding(.top, 50)
                            .padding(.leading, 16)
                            
                            Spacer()
                        }
                        Spacer()
                    }
                }
                
                // Right-side button panel
                PlayerButtonPanel(
                    provider: viewModel,
                    showSettingsButton: false,
                    trimAction: {
                        // Trigger trimming to be shown in the parent view
                        NotificationCenter.default.post(name: .startVideoTrimming, object: nil)
                    }
                )
                .padding(.trailing, 8)
                .padding(.top, 50)
            }
        }
    }
}