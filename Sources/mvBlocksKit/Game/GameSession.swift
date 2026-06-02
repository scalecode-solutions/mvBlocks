import Foundation

/// The game's logical state and rules — pure, UI-agnostic, value-type-friendly.
/// Time-driven gravity (the auto-drop tick) is driven from the UI layer, which
/// calls `step()` on a cadence from `Gravity.interval(forLevel:)`. Everything
/// here is synchronous and deterministic given a seed.
public struct GameSession: Sendable {
    public private(set) var board: BoardGrid
    public private(set) var status: GameStatus
    public private(set) var scoring: Scoring
    public private(set) var active: ActivePiece?
    /// Two reserve slots. Park the current pentomino into an empty slot, or swap
    /// it back from a filled one — once per spawned piece.
    public private(set) var holds: [Pentomino?] = [nil, nil]
    /// Remaining boost charges by type.
    public private(set) var boosts: [Boost: Int]
    /// A boost the player has armed to spawn next, ahead of the bag.
    public private(set) var queuedBoost: Boost?
    /// Bumped each time rows clear — the UI watches this to fire a flash.
    public private(set) var clearEventID = 0
    /// The (pre-clear) row indices cleared by the most recent lock.
    public private(set) var lastClearedRows: [Int] = []
    /// Bumped on a "big" clear (2+ rows) — the UI watches this for a burst.
    public private(set) var celebrationEventID = 0
    /// Bumped each detonation — the UI watches this for the explosion overlay.
    public private(set) var detonationEventID = 0
    private var holdUsedThisTurn = false
    private var linesTowardBomb = 0
    private var linesTowardSuperbomb = 0
    private var bag: Bag

    /// Starting free charges.
    public static let startingSingles = 5
    public static let startingBombs = 3
    /// Singles earned per row cleared.
    public static let singlesPerLine = 1
    /// Rows that must clear to earn one bomb (stingier than singles — bombs are
    /// powerful).
    public static let linesPerBomb = 3
    /// Rows that must clear to earn one superbomb (the nuke).
    public static let linesPerSuperbomb = 10

    public init(seed: UInt64 = 0x5EED, board: BoardGrid = BoardGrid()) {
        self.board = board
        self.status = .ready
        self.scoring = Scoring()
        self.bag = Bag(seed: seed)
        self.active = nil
        self.boosts = [.single: GameSession.startingSingles, .bomb: GameSession.startingBombs, .superbomb: 0]
        self.queuedBoost = nil
    }

    /// Number of 1×1 bombs currently resting on the board (for BOOM).
    public var bombsOnBoard: Int { board.bombCells().count }
    /// Whether a superbomb is resting on the board (for BIG BOOM).
    public var hasSuperbombOnBoard: Bool { !board.superbombCells().isEmpty }

    /// Upcoming pentominoes for the preview queue (the bag order, ignoring any
    /// armed boost — that's surfaced separately via `queuedBoost`).
    public func nextQueue(_ count: Int = 5) -> [Pentomino] {
        bag.peek(count)
    }

    /// Where the active piece would land if hard-dropped — for the ghost.
    public var ghost: ActivePiece? {
        guard status == .playing, let piece = active else { return nil }
        var current = piece
        while board.fits(current.moved(by: Coord(0, 1)).absoluteCells) {
            current = current.moved(by: Coord(0, 1))
        }
        return current
    }

    // MARK: - Lifecycle

    public mutating func start() {
        status = .playing
        spawn()
    }

    public mutating func togglePause() {
        switch status {
        case .playing: status = .paused
        case .paused: status = .playing
        default: break
        }
    }

    /// Spawn the next piece centered at the top — an armed boost if one is
    /// queued, otherwise the next pentomino from the bag. If it can't be
    /// placed, the stack has topped out — game over.
    private mutating func spawn() {
        holdUsedThisTurn = false
        let kind: PieceKind
        if let queued = queuedBoost {
            kind = .boost(queued)
            queuedBoost = nil
        } else {
            kind = .pentomino(bag.next())
        }
        let orientation = kind.orientations[0]
        let startX = max(0, (board.width - orientation.width) / 2)
        let candidate = ActivePiece(kind: kind, orientationIndex: 0, origin: Coord(startX, 0))
        active = candidate
        if !board.fits(candidate.absoluteCells) {
            status = .gameOver
        }
    }

    // MARK: - Input

    /// Arm a boost to spawn next. Consumes a charge immediately; only one boost
    /// can be queued at a time. Returns whether it was armed.
    @discardableResult
    public mutating func queueBoost(_ boost: Boost) -> Bool {
        guard status == .playing, queuedBoost == nil, (boosts[boost] ?? 0) > 0 else {
            return false
        }
        boosts[boost, default: 0] -= 1
        queuedBoost = boost
        return true
    }

    /// Apply a player move. Returns true if the board state changed.
    @discardableResult
    public mutating func apply(_ move: Move) -> Bool {
        guard status == .playing, let piece = active else { return false }
        switch move {
        case .left:      return tryReplace(piece.moved(by: Coord(-1, 0)))
        case .right:     return tryReplace(piece.moved(by: Coord(1, 0)))
        case .rotateCW:  return tryRotate(piece, clockwise: true)
        case .rotateCCW: return tryRotate(piece, clockwise: false)
        case .flip:      return tryFlip(piece)
        case .softDrop:  return gravityStep()
        case .hardDrop:  return hardDrop()
        case .hold:      return toggleHold(slot: holds.firstIndex(where: { $0 == nil }) ?? 0)
        }
    }

    /// Detonate every resting bomb: each clears its row + column, all together,
    /// so bombs sharing a row/column cascade into one big clear. Scores by cells
    /// removed × bomb count. Returns cells cleared.
    @discardableResult
    public mutating func detonateBombs() -> Int {
        guard status == .playing else { return 0 }
        let bombs = board.bombCells()
        guard !bombs.isEmpty else { return 0 }
        let cleared = board.detonate(bombs)
        scoring.registerBombClear(cells: cleared, bombs: bombs.count)
        detonationEventID += 1
        return cleared
    }

    /// BIG BOOM: detonate all resting superbombs (6×6 block + their full
    /// rows/columns). Returns cells cleared.
    @discardableResult
    public mutating func detonateSuperbombs() -> Int {
        guard status == .playing, hasSuperbombOnBoard else { return 0 }
        let cleared = board.detonateSuperbombs()
        scoring.registerBombClear(cells: cleared, bombs: 4)
        detonationEventID += 1
        return cleared
    }

    /// Whether the active piece is resting on the stack/floor (can't fall).
    public var isGrounded: Bool {
        guard status == .playing, let piece = active else { return false }
        return !board.fits(piece.moved(by: Coord(0, 1)).absoluteCells)
    }

    /// Advance gravity one cell if possible. Does NOT lock — locking is driven
    /// by the UI's lock-delay timer via `lockActive()`. Returns whether it moved.
    @discardableResult
    public mutating func gravityStep() -> Bool {
        guard status == .playing, let piece = active else { return false }
        let dropped = piece.moved(by: Coord(0, 1))
        guard board.fits(dropped.absoluteCells) else { return false }
        active = dropped
        return true
    }

    /// Lock the active piece in place (settle, clear, spawn next). Call when the
    /// lock-delay elapses with the piece still grounded.
    public mutating func lockActive() {
        guard status == .playing, let piece = active else { return }
        lock(piece)
    }

    // MARK: - Move helpers

    private mutating func tryReplace(_ candidate: ActivePiece) -> Bool {
        guard board.fits(candidate.absoluteCells) else { return false }
        active = candidate
        return true
    }

    /// Rotation with a small set of wall-kick offsets (our own table, not SRS).
    private mutating func tryRotate(_ piece: ActivePiece, clockwise: Bool) -> Bool {
        tryWithKicks(piece.rotated(clockwise: clockwise))
    }

    /// Flip across the vertical axis. Only meaningful for chiral pentominoes;
    /// reaches their mirror shape. A no-op for symmetric pieces and boosts.
    private mutating func tryFlip(_ piece: ActivePiece) -> Bool {
        guard case .pentomino(let p) = piece.kind, p.isChiral else { return false }
        let mirrored = Orientation(Orientation.reflect(piece.orientation.cells))
        guard let idx = piece.kind.orientations.firstIndex(of: mirrored) else { return false }
        var candidate = piece
        candidate.orientationIndex = idx
        return tryWithKicks(candidate)
    }

    private static let kicks = [Coord(0, 0), Coord(-1, 0), Coord(1, 0), Coord(-2, 0), Coord(2, 0), Coord(0, -1)]

    private mutating func tryWithKicks(_ candidate: ActivePiece) -> Bool {
        for kick in GameSession.kicks {
            let kicked = candidate.moved(by: kick)
            if board.fits(kicked.absoluteCells) {
                active = kicked
                return true
            }
        }
        return false
    }

    @discardableResult
    private mutating func hardDrop() -> Bool {
        guard let piece = active else { return false }
        var distance = 0
        var current = piece
        while board.fits(current.moved(by: Coord(0, 1)).absoluteCells) {
            current = current.moved(by: Coord(0, 1))
            distance += 1
        }
        scoring.addDropBonus(cells: distance)
        active = current
        lock(current)
        return true
    }

    /// Park the current pentomino into reserve `slot` (empty), or swap it back
    /// in (filled). Once per spawned piece; boosts can't be stashed.
    @discardableResult
    public mutating func toggleHold(slot: Int) -> Bool {
        guard status == .playing, !holdUsedThisTurn, let piece = active,
              holds.indices.contains(slot),
              case .pentomino(let current) = piece.kind else { return false }
        if let stashed = holds[slot] {
            holds[slot] = current
            let orientation = stashed.orientations[0]
            let startX = max(0, (board.width - orientation.width) / 2)
            active = ActivePiece(kind: .pentomino(stashed), origin: Coord(startX, 0))
        } else {
            holds[slot] = current
            spawn()
        }
        // Set after spawn() (which resets the flag) so it's truly once-per-piece.
        holdUsedThisTurn = true
        return true
    }

    /// Settle a piece, resolve line clears, award boost charges, then spawn the
    /// next piece.
    private mutating func lock(_ piece: ActivePiece) {
        board.settle(piece.absoluteCells, as: piece.kind)
        let rows = board.fullRows()
        // A bomb caught in a line clear isn't destroyed or auto-detonated — it
        // returns to your inventory. Clearing a line you built shouldn't cost
        // you a bomb or blow up the pattern around it.
        let recoveredBombs = rows.reduce(0) { sum, y in
            sum + board.cells[y].lazy.filter { $0 == .boost(.bomb) }.count
        }
        let cleared = board.clearRows(rows)
        scoring.registerLock(rowsCleared: cleared)
        if cleared > 0 {
            boosts[.single, default: 0] += cleared * GameSession.singlesPerLine
            linesTowardBomb += cleared
            while linesTowardBomb >= GameSession.linesPerBomb {
                boosts[.bomb, default: 0] += 1
                linesTowardBomb -= GameSession.linesPerBomb
            }
            linesTowardSuperbomb += cleared
            while linesTowardSuperbomb >= GameSession.linesPerSuperbomb {
                boosts[.superbomb, default: 0] += 1
                linesTowardSuperbomb -= GameSession.linesPerSuperbomb
            }
            lastClearedRows = rows
            clearEventID += 1
            if cleared >= 2 { celebrationEventID += 1 }
        }
        if recoveredBombs > 0 {
            boosts[.bomb, default: 0] += recoveredBombs
        }
        active = nil
        spawn()
    }
}
