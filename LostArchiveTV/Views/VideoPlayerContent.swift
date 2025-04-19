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
            Color.black
            
            VideoPlayer(player: player)
                .disabled(true) // Disable VideoPlayer's own gestures
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .edgesIgnoringSafeArea(.all)
    }
}

#Preview {
    // Use a mock player for preview
    let player = AVPlayer()
    let viewModel = VideoPlayerViewModel()
    return VideoPlayerContent(player: player, viewModel: viewModel)
}