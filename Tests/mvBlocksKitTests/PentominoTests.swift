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

    @Test("Single boost has one cell, double has two")
    func boostCellCounts() {
        #expect(Boost.single.baseCells.count == 1)
        #expect(Boost.double.baseCells.count == 2)
    }

    @Test("A new session starts with five of each boost")
    func startingInventory() {
        let session = GameSession()
        #expect(session.boosts[.single] == 5)
        #expect(session.boosts[.double] == 5)
    }

    @Test("Queuing a boost consumes a charge and arms the next spawn")
    func queueConsumesCharge() {
        var session = GameSession()
        session.start()
        #expect(session.queueBoost(.single) == true)
        #expect(session.boosts[.single] == 4)
        #expect(session.queuedBoost == .single)
        // Only one boost can be armed at a time.
        #expect(session.queueBoost(.double) == false)
        #expect(session.boosts[.double] == 5)
    }

    @Test("An armed boost is the next piece to spawn")
    func armedBoostSpawnsNext() {
        var session = GameSession()
        session.start()
        session.queueBoost(.single)
        // Hard-drop the current piece to force the next spawn.
        session.apply(.hardDrop)
        #expect(session.active?.kind == .boost(.single))
        #expect(session.queuedBoost == nil)
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
