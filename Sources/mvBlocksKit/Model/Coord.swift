import Foundation

/// An integer grid coordinate. `x` increases to the right, `y` increases
/// downward (screen/board convention), so a piece "falls" by increasing `y`.
public struct Coord: Hashable, Sendable, Codable, Comparable {
    public var x: Int
    public var y: Int

    public init(_ x: Int, _ y: Int) {
        self.x = x
        self.y = y
    }

    public static func + (lhs: Coord, rhs: Coord) -> Coord {
        Coord(lhs.x + rhs.x, lhs.y + rhs.y)
    }

    public static func - (lhs: Coord, rhs: Coord) -> Coord {
        Coord(lhs.x - rhs.x, lhs.y - rhs.y)
    }

    /// Row-major ordering — used to produce a canonical, comparable cell list.
    public static func < (lhs: Coord, rhs: Coord) -> Bool {
        (lhs.y, lhs.x) < (rhs.y, rhs.x)
    }
}
