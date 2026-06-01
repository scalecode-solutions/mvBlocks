import Foundation

/// One concrete placement-shape of a piece: a normalized, canonically-ordered
/// set of five cells. Two orientations are equal iff they cover the same cells.
public struct Orientation: Hashable, Sendable, Codable {
    /// Cells normalized so min x == 0 and min y == 0, sorted row-major.
    public let cells: [Coord]

    public init(_ cells: [Coord]) {
        self.cells = Orientation.normalize(cells)
    }

    /// Width of the orientation's bounding box, in cells.
    public var width: Int { (cells.map(\.x).max() ?? -1) + 1 }

    /// Height of the orientation's bounding box, in cells.
    public var height: Int { (cells.map(\.y).max() ?? -1) + 1 }

    // MARK: - Transforms

    /// Rotate 90° clockwise (screen space: y grows down, so CW is x,y -> -y,x... ).
    /// We use (x, y) -> (-y, x) then normalize, which is a clean quarter turn;
    /// orientation dedup makes the exact handedness immaterial.
    static func rotateCW(_ cells: [Coord]) -> [Coord] {
        cells.map { Coord(-$0.y, $0.x) }
    }

    /// Mirror across the vertical axis: (x, y) -> (-x, y).
    static func reflect(_ cells: [Coord]) -> [Coord] {
        cells.map { Coord(-$0.x, $0.y) }
    }

    /// Shift so the bounding box starts at (0, 0), then sort row-major.
    static func normalize(_ cells: [Coord]) -> [Coord] {
        guard let minX = cells.map(\.x).min(), let minY = cells.map(\.y).min() else {
            return []
        }
        return cells.map { Coord($0.x - minX, $0.y - minY) }.sorted()
    }

    /// Every distinct fixed orientation of a base shape: the 4 rotations of the
    /// shape and the 4 rotations of its reflection, deduplicated by cell set.
    static func allFixed(of base: [Coord]) -> [Orientation] {
        var seen = Set<[Coord]>()
        var result: [Orientation] = []

        for start in [base, reflect(base)] {
            var current = start
            for _ in 0..<4 {
                let normalized = normalize(current)
                if seen.insert(normalized).inserted {
                    result.append(Orientation(normalized))
                }
                current = rotateCW(current)
            }
        }
        return result
    }
}
