import Foundation

/// The twelve free pentominoes, named by the letters they resemble:
/// `F I L N P T U V W X Y Z`. Each is defined once by a base cell layout;
/// every rotation and reflection is derived from it by `Orientation`.
public enum Pentomino: String, CaseIterable, Sendable, Codable, Identifiable, Hashable {
    case f, i, l, n, p, t, u, v, w, x, y, z

    public var id: String { rawValue }

    /// Single-letter display label, e.g. "F".
    public var label: String { rawValue.uppercased() }

    /// Whether the piece is *chiral* — i.e. its mirror image is a genuinely
    /// different shape that rotation alone can't reach. These six are the
    /// pieces the player can meaningfully **flip**; the other six are
    /// reflection-symmetric and flipping is a no-op (or a plain rotation).
    public var isChiral: Bool {
        switch self {
        case .f, .l, .n, .p, .y, .z: true
        case .i, .t, .u, .v, .w, .x: false
        }
    }

    /// The canonical 5-cell layout in local coordinates, normalized so the
    /// minimum x and y are both 0. `y` grows downward, matching the board.
    public var baseCells: [Coord] {
        switch self {
        // .XX
        // XX.
        // .X.
        case .f: [Coord(1, 0), Coord(2, 0), Coord(0, 1), Coord(1, 1), Coord(1, 2)]
        // X
        // X
        // X
        // X
        // X
        case .i: [Coord(0, 0), Coord(0, 1), Coord(0, 2), Coord(0, 3), Coord(0, 4)]
        // X.
        // X.
        // X.
        // XX
        case .l: [Coord(0, 0), Coord(0, 1), Coord(0, 2), Coord(0, 3), Coord(1, 3)]
        // .X
        // .X
        // XX
        // X.
        case .n: [Coord(1, 0), Coord(1, 1), Coord(0, 2), Coord(1, 2), Coord(0, 3)]
        // XX
        // XX
        // X.
        case .p: [Coord(0, 0), Coord(1, 0), Coord(0, 1), Coord(1, 1), Coord(0, 2)]
        // XXX
        // .X.
        // .X.
        case .t: [Coord(0, 0), Coord(1, 0), Coord(2, 0), Coord(1, 1), Coord(1, 2)]
        // X.X
        // XXX
        case .u: [Coord(0, 0), Coord(2, 0), Coord(0, 1), Coord(1, 1), Coord(2, 1)]
        // X..
        // X..
        // XXX
        case .v: [Coord(0, 0), Coord(0, 1), Coord(0, 2), Coord(1, 2), Coord(2, 2)]
        // X..
        // XX.
        // .XX
        case .w: [Coord(0, 0), Coord(0, 1), Coord(1, 1), Coord(1, 2), Coord(2, 2)]
        // .X.
        // XXX
        // .X.
        case .x: [Coord(1, 0), Coord(0, 1), Coord(1, 1), Coord(2, 1), Coord(1, 2)]
        // .X
        // XX
        // .X
        // .X
        case .y: [Coord(1, 0), Coord(0, 1), Coord(1, 1), Coord(1, 2), Coord(1, 3)]
        // XX.
        // .X.
        // .XX
        case .z: [Coord(0, 0), Coord(1, 0), Coord(1, 1), Coord(1, 2), Coord(2, 2)]
        }
    }

    /// All distinct fixed orientations (rotations × reflections), deduped.
    /// Counts per piece: F8 I2 L8 N8 P8 T4 U4 V4 W4 X1 Y8 Z4 — 63 total.
    public var orientations: [Orientation] {
        Orientation.allFixed(of: baseCells)
    }
}
