import Foundation

/// Lifecycle of a single game.
public enum GameStatus: Sendable, Hashable, Codable {
    case ready
    case playing
    case paused
    case gameOver
}
