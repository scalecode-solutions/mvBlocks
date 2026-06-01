import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Thin wrapper over the platform haptic generators. No-ops on platforms
/// without UIKit (e.g. macOS test runs).
public enum Haptics {
    public enum Event: Sendable {
        case move
        case flip
        case lock
        case lineClear
        case blocksOut
        case levelUp
        case gameOver
    }

    public static func play(_ event: Event) {
        #if canImport(UIKit)
        switch event {
        case .move:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .flip:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case .lock:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .lineClear:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .blocksOut:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .levelUp:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .gameOver:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        #endif
    }
}
