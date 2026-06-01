import SwiftUI
import mvBlocksKit
import mvBlocksUI

@main
struct mvBlocksDemoApp: App {

    /// SwiftData-backed store constructed once at launch, falling back to
    /// UserDefaults if the container can't open.
    private let progressStore: any ProgressStore

    init() {
        do {
            progressStore = try SwiftDataProgressStore()
        } catch {
            assertionFailure("SwiftDataProgressStore init failed: \(error)")
            progressStore = UserDefaultsProgressStore()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(progressStore: progressStore)
                .blocksTheme(.neonNursery)
                .preferredColorScheme(.dark)
        }
    }
}
