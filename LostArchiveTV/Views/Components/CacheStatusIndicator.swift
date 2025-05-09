import SwiftUI

enum CacheStatus {
    case notCached
    case cached
    case preloaded
}

struct CacheStatusIndicator: View {
    let cacheStatuses: [CacheStatus]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<min(cacheStatuses.count, 3), id: \.self) { index in
                Circle()
                    .stroke(
                        cacheStatuses[index] == .notCached ? Color.white.opacity(0.3) : Color.green.opacity(0.7),
                        lineWidth: 1.5
                    )
                    .background(
                        Circle()
                            .fill(cacheStatuses[index] == .preloaded ? Color.green.opacity(0.5) : Color.clear)
                    )
                    .frame(width: 10, height: 10)
            }
        }
        .padding(.horizontal, 4)
    }
}

#Preview {
    ZStack {
        Color.black
        VStack(spacing: 20) {
            CacheStatusIndicator(cacheStatuses: [.notCached, .notCached, .notCached])
            CacheStatusIndicator(cacheStatuses: [.cached, .notCached, .notCached])
            CacheStatusIndicator(cacheStatuses: [.preloaded, .cached, .notCached])
            CacheStatusIndicator(cacheStatuses: [.preloaded, .cached, .cached])
        }
    }
}