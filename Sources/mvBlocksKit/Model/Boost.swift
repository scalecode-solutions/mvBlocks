import Foundation

/// Player-deployable helper pieces — small shapes you can inject into the next
/// spawn to fill the awkward gaps pentominoes leave behind. You start with a
/// few of each for free and earn more by clearing rows.
public enum Boost: String, CaseIterable, Sendable, Codable, Hashable, Identifiable {
    /// A single 1×1 cell.
    case single
    /// A 1×2 domino (rotatable to 2×1).
    case double

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .single: "Single"
        case .double: "Double"
        }
    }

    public var baseCells: [Coord] {
        switch self {
        case .single: [Coord(0, 0)]
        case .double: [Coord(0, 0), Coord(0, 1)]
        }
    }

    /// Distinct orientations: single → 1, double → 2 (vertical + horizontal).
    public var orientations: [Orientation] {
        Orientation.allFixed(of: baseCells)
    }
}
