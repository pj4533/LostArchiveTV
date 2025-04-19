//
//  HeaderView.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import SwiftUI

struct HeaderView: View {
    var body: some View {
        Text("Internet Archive Video Player")
            .font(.title2)
            .padding()
    }
}

#Preview {
    HeaderView()
        .preferredColorScheme(.dark)
}
