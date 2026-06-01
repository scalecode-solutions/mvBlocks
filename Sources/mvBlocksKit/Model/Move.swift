import Foundation

/// A player input against the active piece.
public enum Move: Sendable, Hashable, Codable {
    case left
    case right
    case rotateCW
    case rotateCCW
    /// Mirror the active piece across its vertical axis — the signature
    /// Blocks mechanic. A no-op for reflection-symmetric pieces.
    case flip
    case softDrop
    case hardDrop
    case hold
}
