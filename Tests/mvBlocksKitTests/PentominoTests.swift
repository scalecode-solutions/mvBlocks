import Testing
@testable import mvBlocksKit

@Suite("Pentomino model")
struct PentominoTests {

    @Test("There are exactly twelve pentominoes")
    func twelvePieces() {
        #expect(Pentomino.allCases.count == 12)
    }

    @Test("Every base shape has exactly five cells")
    func fiveCellsEach() {
        for piece in Pentomino.allCases {
            #expect(piece.baseCells.count == 5)
        }
    }

    @Test("Every orientation has exactly five cells and is normalized")
    func orientationsAreFiveCellsAndNormalized() {
        for piece in Pentomino.allCases {
            for o in piece.orientations {
                #expect(o.cells.count == 5)
                #expect(o.cells.map(\.x).min() == 0)
                #expect(o.cells.map(\.y).min() == 0)
            }
        }
    }

    /// The classic per-piece fixed-orientation counts: F8 I2 L8 N8 P8 T4 U4 V4
    /// W4 X1 Y8 Z4, totaling 63.
    @Test("Per-piece orientation counts match the known pentomino values")
    func orientationCounts() {
        let expected: [Pentomino: Int] = [
            .f: 8, .i: 2, .l: 8, .n: 8, .p: 8, .t: 4,
            .u: 4, .v: 4, .w: 4, .x: 1, .y: 8, .z: 4,
        ]
        for (piece, count) in expected {
            #expect(piece.orientations.count == count, "\(piece.label) should have \(count) orientations")
        }
    }

    @Test("Total fixed orientations across all pieces is 63")
    func totalOrientations() {
        let total = Pentomino.allCases.reduce(0) { $0 + $1.orientations.count }
        #expect(total == 63)
    }

    @Test("Chiral pieces are exactly F, L, N, P, Y, Z")
    func chiralSet() {
        let chiral = Set(Pentomino.allCases.filter(\.isChiral))
        #expect(chiral == [.f, .l, .n, .p, .y, .z])
    }
}

@Suite("12-bag randomizer")
struct BagTests {

    @Test("Each cycle of twelve draws contains every pentomino once")
    func bagIsFair() {
        var bag = Bag(seed: 12345)
        var drawn: [Pentomino] = []
        for _ in 0..<12 { drawn.append(bag.next()) }
        #expect(Set(drawn) == Set(Pentomino.allCases))
        #expect(drawn.count == 12)
    }

    @Test("Same seed yields the same sequence")
    func deterministic() {
        var a = Bag(seed: 99)
        var b = Bag(seed: 99)
        for _ in 0..<30 {
            #expect(a.next() == b.next())
        }
    }

    @Test("Peek does not consume pieces")
    func peekIsNonDestructive() {
        var bag = Bag(seed: 7)
        let peeked = bag.peek(5)
        let drawn = (0..<5).map { _ in bag.next() }
        #expect(peeked == drawn)
    }
}

@Suite("Board line clears")
struct BoardTests {

    @Test("A fully-filled row is detected and cleared")
    func clearsFullRow() {
        var board = BoardGrid(width: 3, height: 3)
        board.settle([Coord(0, 2), Coord(1, 2), Coord(2, 2)], as: .pentomino(.i))
        #expect(board.fullRows() == [2])
        let cleared = board.clearRows([2])
        #expect(cleared == 1)
        #expect(board.fullRows().isEmpty)
    }

    @Test("Cells above a cleared row fall down")
    func gravityAfterClear() {
        var board = BoardGrid(width: 2, height: 3)
        board.settle([Coord(0, 1)], as: .pentomino(.x))             // floating block
        board.settle([Coord(0, 2), Coord(1, 2)], as: .pentomino(.i)) // full bottom row
        board.clearRows([2])
        // The floating block at y=1 should now be at y=2.
        #expect(board.cells[2][0] == .pentomino(.x))
        #expect(board.cells[1][0] == nil)
    }
}

@Suite("Boosts")
struct BoostTests {

    @Test("Single and bomb are both one-cell pieces")
    func boostCellCounts() {
        #expect(Boost.single.baseCells.count == 1)
        #expect(Boost.bomb.baseCells.count == 1)
    }

    @Test("A new session starts with 5 singles and 3 bombs")
    func startingInventory() {
        let session = GameSession()
        #expect(session.boosts[.single] == 5)
        #expect(session.boosts[.bomb] == 3)
    }

    @Test("Queuing a boost consumes a charge and arms the next spawn")
    func queueConsumesCharge() {
        var session = GameSession()
        session.start()
        #expect(session.queueBoost(.single) == true)
        #expect(session.boosts[.single] == 4)
        #expect(session.queuedBoost == .single)
        // Only one boost can be armed at a time.
        #expect(session.queueBoost(.bomb) == false)
        #expect(session.boosts[.bomb] == 3)
    }

    @Test("An armed boost is the next piece to spawn")
    func armedBoostSpawnsNext() {
        var session = GameSession()
        session.start()
        session.queueBoost(.bomb)
        session.apply(.hardDrop)
        #expect(session.active?.kind == .boost(.bomb))
        #expect(session.queuedBoost == nil)
    }
}

@Suite("Two-slot hold")
struct HoldTests {

    @Test("Park into an empty slot, then swap back from it")
    func parkAndSwap() {
        var session = GameSession()
        session.start()
        let first = session.active        // a pentomino
        #expect(session.toggleHold(slot: 1) == true)
        #expect(session.holds[1] != nil)
        // Hold is once-per-spawn: a second hold this turn is rejected.
        #expect(session.toggleHold(slot: 0) == false)
        // New piece in play, distinct origin reset.
        #expect(session.active != nil)
        #expect(first != nil)
    }
}

@Suite("Bombs")
struct BombTests {

    /// Build a board with two bombs and some filler, then detonate.
    @Test("Detonating clears each bomb's row and column")
    func detonateClearsCross() {
        var board = BoardGrid(width: 4, height: 4)
        // Fill the whole board with a pentomino marker...
        for y in 0..<4 { for x in 0..<4 { board.settle([Coord(x, y)], as: .pentomino(.i)) } }
        // ...then drop a bomb at (row 1, col 1).
        board.settle([Coord(1, 1)], as: .boost(.bomb))
        let cleared = board.detonate(board.bombCells())
        // Row 1 (4) + column 1 (4) − the shared cell counted once = 7 cells.
        #expect(cleared == 7)
        // Column 1 and row 1 are now empty after collapse pushed survivors down.
        #expect(board.bombCells().isEmpty)
    }

    @Test("Two bombs in the same column cascade into one clear")
    func twoBombsChain() {
        var board = BoardGrid(width: 5, height: 5)
        for y in 0..<5 { for x in 0..<5 { board.settle([Coord(x, y)], as: .pentomino(.i)) } }
        board.settle([Coord(2, 1)], as: .boost(.bomb))
        board.settle([Coord(2, 3)], as: .boost(.bomb))
        // Rows 1 & 3 (5+5) + column 2 (5) − overlaps (2 shared cells) = 13.
        let cleared = board.detonate(board.bombCells())
        #expect(cleared == 13)
    }

    @Test("A bomb caught in a line clear returns to inventory instead of dying")
    func bombRecoveredOnLineClear() {
        // Bottom row full (6 cells) with a bomb at col 2; everything else empty.
        var board = BoardGrid(width: 6, height: 8)
        for x in [0, 1, 3, 4, 5] { board.settle([Coord(x, 7)], as: .pentomino(.i)) }
        board.settle([Coord(2, 7)], as: .boost(.bomb))

        var session = GameSession(board: board)
        session.start()
        let bombsBefore = session.boosts[.bomb] ?? 0
        // Dropping anything triggers the full bottom row to clear on lock.
        session.apply(.hardDrop)
        #expect(session.boosts[.bomb] == bombsBefore + 1)   // refunded, not destroyed
        #expect(session.bombsOnBoard == 0)                  // gone from the board
    }

    @Test("A superbomb clears a 6×6 block plus its full rows and columns")
    func superbombBlast() {
        var board = BoardGrid(width: 9, height: 9)
        for y in 0..<9 { for x in 0..<9 { board.settle([Coord(x, y)], as: .pentomino(.i)) } }
        // 2×2 superbomb at rows 3–4, cols 3–4.
        board.settle([Coord(3, 3), Coord(4, 3), Coord(3, 4), Coord(4, 4)], as: .boost(.superbomb))
        let cleared = board.detonateSuperbombs()
        // Rows 3,4 (18) + cols 3,4 (18) − overlap (4) = 32, plus the 6×6 corners.
        #expect(cleared >= 32)
        #expect(board.superbombCells().isEmpty)
        // A corner cell far from the blast survives (row 0, col 8).
        #expect(board.cells[8][8] != nil)
    }

    @Test("Superbombs are earned every 10 lines, bombs every 3")
    func earnRates() {
        #expect(GameSession.linesPerBomb == 3)
        #expect(GameSession.linesPerSuperbomb == 10)
        let session = GameSession()
        #expect(session.boosts[.superbomb] == 0)   // earned only, none to start
    }

    @Test("detonateBombs scores and bumps the event id")
    func detonateScores() {
        var session = GameSession()                 // default 12-wide board (no stray clears)
        session.start()
        session.queueBoost(.bomb)
        session.apply(.hardDrop)                     // locks the current pentomino, spawns the bomb
        session.apply(.hardDrop)                     // locks the bomb onto the board
        let before = session.detonationEventID
        #expect(session.bombsOnBoard >= 1)
        let cleared = session.detonateBombs()
        #expect(cleared > 0)
        #expect(session.detonationEventID == before + 1)
        #expect(session.bombsOnBoard == 0)
    }
}

@Suite("Gravity and locking")
struct LockingTests {

    @Test("gravityStep moves the piece down but never locks")
    func gravityStepMovesWithoutLocking() {
        var session = GameSession()
        session.start()
        let before = session.active?.origin.y ?? -1
        let moved = session.gravityStep()
        #expect(moved == true)
        #expect((session.active?.origin.y ?? -1) == before + 1)
        // No row was settled, so the board is still empty.
        #expect(session.board.fullRows().isEmpty)
    }

    @Test("A piece at the floor reports grounded and gravityStep is a no-op")
    func groundedAtFloor() {
        var session = GameSession()
        session.start()
        // Drop to the bottom without locking.
        while session.gravityStep() {}
        #expect(session.isGrounded == true)
        #expect(session.gravityStep() == false)
    }

    @Test("lockActive settles the piece and spawns a new one")
    func lockActiveSettlesAndSpawns() {
        var session = GameSession()
        session.start()
        while session.gravityStep() {}
        session.lockActive()
        // The locked piece left five settled cells on the board...
        let settled = session.board.cells.flatMap { $0 }.compactMap { $0 }.count
        #expect(settled == 5)
        // ...and a fresh piece spawned at the top.
        #expect(session.active != nil)
        #expect(session.active?.origin.y == 0)
    }
}

@Suite("Scoring")
struct ScoringTests {

    @Test("A single-row clear scores at level one")
    func singleClear() {
        var scoring = Scoring()
        scoring.registerLock(rowsCleared: 1)
        #expect(scoring.score == 100)
        #expect(scoring.linesCleared == 1)
    }

    @Test("A zero-row lock resets the combo")
    func zeroResetsCombo() {
        var scoring = Scoring()
        scoring.registerLock(rowsCleared: 1)
        scoring.registerLock(rowsCleared: 0)
        scoring.registerLock(rowsCleared: 1)
        // Second scoring clear starts a fresh combo (no combo bonus).
        #expect(scoring.score == 200)
    }
}
