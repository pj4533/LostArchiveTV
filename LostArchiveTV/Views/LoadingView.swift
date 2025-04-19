//
//  LoadingView.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import SwiftUI

struct LoadingView: View {
    var message: String = "Loading videos..."
    var progress: Double?
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                if let progress = progress {
                    // Show progress indicator with percentage
                    ProgressView(value: progress, total: 1.0) {
                        Text(message)
                            .font(.headline)
                            .foregroundColor(.white)
                    } currentValueLabel: {
                        Text("\(Int(progress * 100))%")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .padding()
                } else {
                    // Show indeterminate spinner
                    ProgressView {
                        Text(message)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .padding()
                }
                
                // Show a helpful message
                Text("Preparing a random selection from the Internet Archive")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: 300)
            .background(Color.black.opacity(0.7))
            .cornerRadius(16)
            .shadow(radius: 10)
        }
    }
}

#Preview {
    LoadingView(message: "Loading videos...", progress: 0.33)
        .preferredColorScheme(.dark)
}

#Preview {
    LoadingView(message: "Fetching video metadata...")
        .preferredColorScheme(.dark)
}