import Foundation

/// The fixed playfield. Pentominoes need more room than tetrominoes, so the
/// default well is wider than the classic 10.
public struct BoardGrid: Sendable, Codable {
    public static let defaultWidth = 12
    public static let defaultHeight = 18

    public let width: Int
    public let height: Int

    /// Settled cells, row-major: `cells[y][x]` is the piece occupying that
    /// square, or nil if empty. The active falling piece is *not* stored here.
    public private(set) var cells: [[PieceKind?]]

    public init(width: Int = defaultWidth, height: Int = defaultHeight) {
        self.width = width
        self.height = height
        self.cells = Array(
            repeating: Array<PieceKind?>(repeating: nil, count: width),
            count: height
        )
    }

    public func isInside(_ c: Coord) -> Bool {
        c.x >= 0 && c.x < width && c.y >= 0 && c.y < height
    }

    public func isEmpty(_ c: Coord) -> Bool {
        isInside(c) && cells[c.y][c.x] == nil
    }

    /// True if every cell is in-bounds and unoccupied — i.e. a legal placement.
    public func fits(_ absoluteCells: [Coord]) -> Bool {
        absoluteCells.allSatisfy(isEmpty)
    }

    /// Lock a piece's cells into the grid. Caller guarantees `fits` was true.
    public mutating func settle(_ absoluteCells: [Coord], as kind: PieceKind) {
        for c in absoluteCells where isInside(c) {
            cells[c.y][c.x] = kind
        }
    }

    /// Indices of fully-filled rows, top to bottom.
    public func fullRows() -> [Int] {
        (0..<height).filter { y in cells[y].allSatisfy { $0 != nil } }
    }

    /// Remove the given rows and drop everything above them down. Returns the
    /// number of rows cleared.
    @discardableResult
    public mutating func clearRows(_ rows: [Int]) -> Int {
        guard !rows.isEmpty else { return 0 }
        let doomed = Set(rows)
        var survivors = (0..<height)
            .filter { !doomed.contains($0) }
            .map { cells[$0] }
        let cleared = height - survivors.count
        let blank = Array<PieceKind?>(repeating: nil, count: width)
        survivors.insert(contentsOf: Array(repeating: blank, count: cleared), at: 0)
        cells = survivors
        return cleared
    }
}
