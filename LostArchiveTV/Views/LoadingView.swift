//
//  LoadingView.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import SwiftUI

struct LoadingView: View {
    var body: some View {
        ProgressView("Fetching video metadata...")
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    LoadingView()
        .preferredColorScheme(.dark)
}
