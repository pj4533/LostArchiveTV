//
//  VideoInfoOverlay.swift
//  LostArchiveTV
//
//  Created by Claude on 4/19/25.
//

import SwiftUI

struct VideoInfoOverlay: View {
    let title: String?
    let collection: String?
    let description: String?
    let identifier: String?
    
    var body: some View {
        VStack {
            Spacer()
            
            // Bottom overlay with title and description
            VStack(alignment: .leading, spacing: 8) {
                // Video title and description
                VStack(alignment: .leading, spacing: 6) {
                    Text(title ?? identifier ?? "Unknown Title")
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if let collection = collection {
                        Text("Collection: \(collection)")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                    
                    Text(description ?? "Internet Archive random video clip")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
                
                // Swipe hint
                Text("Swipe up for next video")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity)
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
    VideoInfoOverlay(
        title: "Sample Video Title",
        collection: "avgeeks",
        description: "This is a sample description for the video that might span multiple lines when displayed in the app.",
        identifier: "sample_id"
    )
    .background(Color.black)
}
