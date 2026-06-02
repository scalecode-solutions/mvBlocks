import Foundation

/// Player-deployable helper pieces. The **single** fills the awkward gaps
/// pentominoes leave; the **bomb** is a 1×1 you place inert, then set off with
/// the Boom button to clear its whole row + column (and chain through any other
/// bombs caught in the blast). You start with a few of each and earn more by
/// clearing rows.
public enum Boost: String, CaseIterable, Sendable, Codable, Hashable, Identifiable {
    /// A single 1×1 filler cell.
    case single
    /// A 1×1 bomb: rests where placed until detonated, then clears its row + column.
    case bomb
    /// A 2×2 superbomb: earned every 10 lines. BIG BOOM clears a 6×6 block around
    /// it plus the full rows and columns it occupies.
    case superbomb

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .single:    "Single"
        case .bomb:      "Bomb"
        case .superbomb: "Super"
        }
    }

    public var baseCells: [Coord] {
        switch self {
        case .single, .bomb: [Coord(0, 0)]
        case .superbomb:     [Coord(0, 0), Coord(1, 0), Coord(0, 1), Coord(1, 1)]
        }
    }

    public var orientations: [Orientation] {
        Orientation.allFixed(of: baseCells)
    }
}
