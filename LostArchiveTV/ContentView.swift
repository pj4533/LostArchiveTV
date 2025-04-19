//
//  ContentView.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import SwiftUI
import AVKit

struct ContentView: View {
    @StateObject private var videoPlayerViewModel = VideoPlayerViewModel()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if videoPlayerViewModel.isLoading {
                LoadingView()
            } else if let player = videoPlayerViewModel.player {
                PlayerContentView(
                    player: player,
                    currentIdentifier: videoPlayerViewModel.currentIdentifier,
                    title: videoPlayerViewModel.currentTitle,
                    description: videoPlayerViewModel.currentDescription
                ) {
                    Task {
                        await videoPlayerViewModel.loadRandomVideo()
                    }
                }
            } else if let error = videoPlayerViewModel.errorMessage {
                ErrorView(error: error) {
                    Task {
                        await videoPlayerViewModel.loadRandomVideo()
                    }
                }
            }
        }
        .task {
            await videoPlayerViewModel.loadRandomVideo()
        }
    }
}

// MARK: - Header View
struct HeaderView: View {
    var body: some View {
        Text("Internet Archive Video Player")
            .font(.title2)
            .padding()
    }
}

// MARK: - Loading View
struct LoadingView: View {
    var body: some View {
        ProgressView("Fetching video metadata...")
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Player Content View
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

// MARK: - Error View
struct ErrorView: View {
    let error: String
    let onRetryTapped: () -> Void
    
    var body: some View {
        VStack {
            Text("Error: \(error)")
                .foregroundColor(.red)
                .padding()
            
            Button("Retry", action: onRetryTapped)
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .padding()
        }
    }
}

#Preview {
    ContentView()
}
