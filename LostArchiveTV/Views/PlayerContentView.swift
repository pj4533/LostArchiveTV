//
//  PlayerContentView.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import SwiftUI
import AVKit

struct PlayerContentView: View {
    let player: AVPlayer
    let currentIdentifier: String?
    let title: String?
    let description: String?
    let onPlayRandomTapped: () -> Void
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Video Player
            VideoPlayer(player: player)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
            
            // TikTok style overlay at bottom
            VStack(alignment: .leading, spacing: 10) {
                // Next button
                Button(action: onPlayRandomTapped) {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Next Video")
                    }
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(25)
                }
                .padding(.bottom, 10)
                
                // Video title and description
                VStack(alignment: .leading, spacing: 5) {
                    Text(title ?? currentIdentifier ?? "Unknown Title")
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(description ?? "Internet Archive random video clip")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 25)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}

#Preview {
    // Create a sample AVPlayer for preview
    let sampleURL = URL(string: "https://example.com/sample.mp4")!
    let player = AVPlayer(url: sampleURL)
    
    return PlayerContentView(
        player: player,
        currentIdentifier: "sample123",
        title: "Sample Video Title",
        description: "This is a sample description for the video that might span multiple lines when displayed in the app interface.",
        onPlayRandomTapped: {}
    )
    .preferredColorScheme(.dark)
}
