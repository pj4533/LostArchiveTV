//
//  VideoInfoOverlay.swift
//  LostArchiveTV
//
//  Created by Claude on 4/19/25.
//

import SwiftUI

struct VideoInfoOverlay: View {
    let title: String?
    let description: String?
    let identifier: String?
    let onNextTapped: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            
            // Bottom overlay with title and description
            VStack(alignment: .leading, spacing: 10) {
                // Next button
                Button(action: onNextTapped) {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
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
                    Text(title ?? identifier ?? "Unknown Title")
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
            
            // Swipe hint
            Text("Swipe up for next video")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .padding(.bottom, 5)
        }
    }
}

#Preview {
    VideoInfoOverlay(
        title: "Sample Video Title",
        description: "This is a sample description for the video that might span multiple lines when displayed in the app.",
        identifier: "sample_id",
        onNextTapped: {}
    )
    .background(Color.black)
}