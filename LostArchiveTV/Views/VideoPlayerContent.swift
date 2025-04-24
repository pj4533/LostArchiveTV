//
//  VideoPlayerContent.swift
//  LostArchiveTV
//
//  Created by Claude on 4/19/25.
//

import SwiftUI
import AVKit

struct VideoPlayerContent: View {
    let player: AVPlayer
    let viewModel: VideoPlayerViewModel
    
    var body: some View {
        ZStack {
            // Black background fills entire area
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Main content with proper spacing
            VStack(spacing: 0) {
                // Add spacing at top to start below the gear icon
                Spacer().frame(height: 70)
                
                // Actual player is contained within available space
                // Make it slightly smaller than full width to avoid edge clipping
                VideoPlayer(player: player)
                    .aspectRatio(contentMode: .fit)
                    .padding(.horizontal, 10)
                
                // Reserve space for the timeline controls to appear here
                Spacer()
                    .frame(height: 110)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                
                // Additional spacer to ensure separation from video info overlay
                Spacer().frame(height: 100)
            }
        }
    }
}

#Preview {
    // Use a mock player for preview
    let player = AVPlayer()
    let viewModel = VideoPlayerViewModel(favoritesManager: FavoritesManager())
    VideoPlayerContent(player: player, viewModel: viewModel)
}