import Foundation

/// The live, falling piece: which kind (pentomino or boost), which orientation,
/// and where its local origin sits on the board.
public struct ActivePiece: Sendable, Hashable, Codable {
    public let kind: PieceKind
    /// Index into the kind's `orientations` array.
    public var orientationIndex: Int
    /// Board position of the orientation's local (0,0).
    public var origin: Coord

    public init(kind: PieceKind, orientationIndex: Int = 0, origin: Coord = Coord(0, 0)) {
        self.kind = kind
        self.orientationIndex = orientationIndex
        self.origin = origin
    }

    public var orientation: Orientation {
        let all = kind.orientations
        return all[((orientationIndex % all.count) + all.count) % all.count]
    }

    /// The piece's cells in absolute board coordinates.
    public var absoluteCells: [Coord] {
        orientation.cells.map { $0 + origin }
    }

    /// A copy rotated one step in the given direction (no collision check).
    public func rotated(clockwise: Bool) -> ActivePiece {
        var copy = self
        copy.orientationIndex = clockwise ? orientationIndex + 1 : orientationIndex - 1
        return copy
    }

    /// A copy shifted by a delta (no collision check).
    public func moved(by delta: Coord) -> ActivePiece {
        var copy = self
        copy.origin = origin + delta
        return copy
    }
}
