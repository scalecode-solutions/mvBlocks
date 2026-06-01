import Foundation

/// What a placeable piece *is* — a standard pentomino or a player boost block.
/// Unifies the two so the board, the active piece, and rendering can treat any
/// shape uniformly.
public enum PieceKind: Hashable, Sendable, Codable {
    case pentomino(Pentomino)
    case boost(Boost)

    /// Distinct fixed orientations for this kind.
    public var orientations: [Orientation] {
        switch self {
        case .pentomino(let p): p.orientations
        case .boost(let b): b.orientations
        }
    }

    /// A short display label (e.g. "F" or "Single").
    public var label: String {
        switch self {
        case .pentomino(let p): p.label
        case .boost(let b): b.label
        }
    }

    public var isBoost: Bool {
        if case .boost = self { return true }
        return false
    }
}
