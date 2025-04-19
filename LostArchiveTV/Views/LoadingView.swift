//
//  LoadingView.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import SwiftUI

struct LoadingView: View {
    @State private var rotationDegrees = 0.0
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Cool animated icon
                Image(systemName: "film.circle")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(rotationDegrees))
                    .onAppear {
                        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                            rotationDegrees = 360
                        }
                    }
                
                // Simple text
                Text("Loading...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
    }
}

#Preview {
    LoadingView()
        .preferredColorScheme(.dark)
}