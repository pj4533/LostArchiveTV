//
//  FastForwardIndicator.swift
//  LostArchiveTV
//
//  Created by Claude on 5/6/25.
//

import SwiftUI

struct FastForwardIndicator: View {
    // Animation configuration
    private let visibleDuration: Double = 2.0
    private let fadeOutDuration: Double = 0.7
    
    var body: some View {
        ZStack {
            // Semi-transparent background circle with shadow for better visibility
            Circle()
                .fill(Color.black.opacity(0.7))
                .frame(width: 100, height: 100)
                .shadow(color: .black.opacity(0.5), radius: 4)
            
            // 2x text and fast-forward icon - larger for better visibility
            VStack(spacing: 4) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                Text("2×")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .transition(.opacity)
        .onAppear {
            // Auto-hide after visibleDuration
            DispatchQueue.main.asyncAfter(deadline: .now() + visibleDuration) {
                withAnimation(.easeOut(duration: fadeOutDuration)) {
                    // The opacity will be handled by the parent view's condition
                }
            }
        }
    }
}

#Preview {
    // Simple preview of just the indicator
    ZStack {
        // Background to simulate video
        Color.gray.opacity(0.5)
            .ignoresSafeArea()
        
        // Indicator overlay
        FastForwardIndicator()
    }
}