//
//  ErrorView.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import SwiftUI

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
    ErrorView(error: "Failed to load video metadata") {}
        .preferredColorScheme(.dark)
}
