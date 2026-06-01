import SwiftUI
import mvBlocksKit
import mvBlocksUI

struct ContentView: View {
    let progressStore: any ProgressStore

    var body: some View {
        BlocksGameView(progressStore: progressStore)
    }
}

#Preview {
    ContentView(progressStore: UserDefaultsProgressStore())
        .blocksTheme(.neonNursery)
        .preferredColorScheme(.dark)
}
