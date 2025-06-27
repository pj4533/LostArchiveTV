import SwiftUI

struct BackButton: View {
    var action: () -> Void
    
    var body: some View {
        PlayerButton.back(action: action)
    }
}