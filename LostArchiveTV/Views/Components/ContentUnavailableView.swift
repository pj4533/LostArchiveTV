import SwiftUI

struct ContentUnavailableView: View {
    let onTryAnother: () -> Void
    let onReturnToSearch: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Icon
                Image(systemName: "video.slash")
                    .font(.system(size: 80))
                    .foregroundColor(.gray)
                    .padding(.bottom, 20)
                
                // Title
                Text("Content No Longer Available")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                // Subtitle
                Text("This video is no longer available on Archive.org")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                // Buttons
                VStack(spacing: 16) {
                    // Primary action button
                    Button(action: onTryAnother) {
                        HStack {
                            Image(systemName: "arrow.forward.circle")
                                .font(.system(size: 20))
                            Text("Try Another Video")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    
                    // Secondary action button
                    Button(action: onReturnToSearch) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 18))
                            Text("Return to Search")
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                }
                .padding(.horizontal, 60)
                .padding(.top, 20)
                
                Spacer()
            }
            .padding()
        }
    }
}

#Preview("Content Unavailable") {
    ContentUnavailableView(
        onTryAnother: {
            print("Try another video tapped")
        },
        onReturnToSearch: {
            print("Return to search tapped")
        }
    )
    .preferredColorScheme(.dark)
}