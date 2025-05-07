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
        // Horizontal indicator at the top of the screen
        HStack(spacing: 6) {
            // Fast-forward icon
            Image(systemName: "forward.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
            
            // 2x text with speed indication
            Text("2× Speed")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.65))
                .shadow(color: .black.opacity(0.3), radius: 3)
        )
        .padding(.top, 10) // Space from the top edge
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