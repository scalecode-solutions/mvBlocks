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

    // MARK: - Bombs

    /// Coordinates of all settled bomb cells, as `Coord(x: col, y: row)`.
    public func bombCells() -> [Coord] {
        var out: [Coord] = []
        for y in 0..<height {
            for x in 0..<width where cells[y][x] == .boost(.bomb) {
                out.append(Coord(x, y))
            }
        }
        return out
    }

    /// Detonate: clear every cell in the rows and columns of the given bombs,
    /// then collapse each column downward. Because *all* given bombs are cleared
    /// together, bombs sharing a row/column fold into one cascade automatically.
    /// Returns the number of cells removed.
    @discardableResult
    public mutating func detonate(_ bombs: [Coord]) -> Int {
        guard !bombs.isEmpty else { return 0 }
        let rows = Set(bombs.map(\.y))
        let cols = Set(bombs.map(\.x))
        var removed = 0
        for y in 0..<height {
            for x in 0..<width where cells[y][x] != nil && (rows.contains(y) || cols.contains(x)) {
                cells[y][x] = nil
                removed += 1
            }
        }
        collapseColumns()
        return removed
    }

    /// Coordinates of all settled superbomb cells.
    public func superbombCells() -> [Coord] {
        var out: [Coord] = []
        for y in 0..<height {
            for x in 0..<width where cells[y][x] == .boost(.superbomb) {
                out.append(Coord(x, y))
            }
        }
        return out
    }

    /// Detonate all superbombs: clear a 6×6 block centered on each (2 cells out
    /// in every direction) plus the full rows and columns they occupy, then
    /// collapse columns. Returns cells removed.
    @discardableResult
    public mutating func detonateSuperbombs() -> Int {
        let supers = superbombCells()
        guard !supers.isEmpty else { return 0 }
        let rows = Set(supers.map(\.y))
        let cols = Set(supers.map(\.x))
        var removed = 0
        for y in 0..<height {
            for x in 0..<width where cells[y][x] != nil {
                let inCross = rows.contains(y) || cols.contains(x)
                let inBlock = supers.contains { abs($0.y - y) <= 2 && abs($0.x - x) <= 2 }
                if inCross || inBlock {
                    cells[y][x] = nil
                    removed += 1
                }
            }
        }
        collapseColumns()
        return removed
    }

    /// Per-column gravity: each column's surviving cells fall to the bottom.
    public mutating func collapseColumns() {
        for x in 0..<width {
            var stack: [PieceKind] = []
            for y in 0..<height {
                if let cell = cells[y][x] { stack.append(cell) }
            }
            let empties = height - stack.count
            for y in 0..<height {
                cells[y][x] = y < empties ? nil : stack[y - empties]
            }
        }
    }
}
