import Testing
import mvBlocksKit
@testable import mvBlocksUI

/// Synchronous input-routing behavior. These assert immediately after each call
/// (well within the first ~0.8s gravity tick), so no timers interfere.
@MainActor
@Suite("BlocksViewModel — input routing")
struct ViewModelInputTests {

    private func settled(_ vm: BlocksViewModel) -> Int {
        vm.session.board.cells.flatMap { $0 }.compactMap { $0 }.count
    }

    @Test("startIfNeeded begins playing with an active piece")
    func startsPlaying() {
        let vm = BlocksViewModel()
        vm.startIfNeeded()
        #expect(vm.session.status == .playing)
        #expect(vm.session.active != nil)
        vm.teardown()
    }

    @Test("left/right move the active piece one column")
    func movesPiece() {
        let vm = BlocksViewModel()
        vm.startIfNeeded()
        let x0 = vm.session.active!.origin.x
        vm.input(.right)
        #expect(vm.session.active!.origin.x == x0 + 1)
        vm.input(.left)
        #expect(vm.session.active!.origin.x == x0)
        vm.teardown()
    }

    @Test("hardDrop locks immediately and spawns a new piece")
    func hardDropLocks() {
        let vm = BlocksViewModel()
        vm.startIfNeeded()
        vm.input(.hardDrop)
        #expect(settled(vm) == 5)
        #expect(vm.session.active?.origin.y == 0)
        vm.teardown()
    }

    @Test("queueBoost arms a boost and decrements inventory")
    func queueBoostArms() {
        let vm = BlocksViewModel()
        vm.startIfNeeded()
        vm.queueBoost(.single)
        #expect(vm.session.queuedBoost == .single)
        #expect(vm.session.boosts[.single] == GameSession.startingSingles - 1)
        vm.teardown()
    }

    @Test("input is ignored while paused")
    func pauseGatesInput() {
        let vm = BlocksViewModel()
        vm.startIfNeeded()
        vm.togglePause()
        #expect(vm.session.status == .paused)
        let x0 = vm.session.active!.origin.x
        vm.input(.right)
        #expect(vm.session.active!.origin.x == x0)
        vm.teardown()
    }

    @Test("newGame resets to a fresh playing board")
    func newGameResets() {
        let vm = BlocksViewModel()
        vm.startIfNeeded()
        vm.input(.hardDrop)            // leave something settled
        #expect(settled(vm) == 5)
        vm.newGame()
        #expect(vm.session.status == .playing)
        #expect(settled(vm) == 0)
        #expect(vm.session.scoring.score == 0)
        vm.teardown()
    }
}

/// Lock-delay timing. Serialized so parallel tests don't perturb the clocks;
/// margins are generous (2–4×) to stay robust under load. The piece is grounded
/// synchronously, which schedules the lock; then we watch the clock.
@MainActor
@Suite("BlocksViewModel — lock delay", .serialized)
struct ViewModelLockDelayTests {

    /// Soft-drop until the piece rests on the floor (schedules the lock timer).
    private func ground(_ vm: BlocksViewModel) {
        while vm.input(.softDrop) {}
    }

    private func settled(_ vm: BlocksViewModel) -> Int {
        vm.session.board.cells.flatMap { $0 }.compactMap { $0 }.count
    }

    @Test("a grounded piece locks after the lock delay elapses")
    func locksAfterDelay() async throws {
        let vm = BlocksViewModel()
        vm.lockDelay = .milliseconds(60)
        vm.startIfNeeded()
        ground(vm)
        #expect(settled(vm) == 0)                       // scheduled, not fired
        try await Task.sleep(for: .milliseconds(250))
        #expect(settled(vm) == 5)                       // locked
        vm.teardown()
    }

    @Test("moving a grounded piece keeps resetting the lock delay")
    func moveResetsDelay() async throws {
        let vm = BlocksViewModel()
        vm.lockDelay = .milliseconds(120)
        vm.maxLockResets = 30
        vm.startIfNeeded()
        ground(vm)
        // Wiggle for longer than one delay; each move resets the timer.
        for _ in 0..<6 {
            try await Task.sleep(for: .milliseconds(40))
            vm.input(.right); vm.input(.left)
        }
        #expect(settled(vm) == 0)                       // never fired while moving
        try await Task.sleep(for: .milliseconds(300))
        #expect(settled(vm) == 5)                       // locks once we stop
        vm.teardown()
    }

    @Test("the reset cap forces a lock even while moving")
    func capForcesLock() async throws {
        let vm = BlocksViewModel()
        vm.lockDelay = .milliseconds(60)
        vm.maxLockResets = 2
        vm.startIfNeeded()
        ground(vm)
        // Keep moving past the cap; after 2 resets the timer must fire anyway.
        for _ in 0..<10 {
            try await Task.sleep(for: .milliseconds(30))
            vm.input(.right); vm.input(.left)
        }
        #expect(settled(vm) >= 5)                       // locked despite moves
        vm.teardown()
    }
}
