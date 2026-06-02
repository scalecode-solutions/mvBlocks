import SwiftUI
import mvBlocksKit

/// Owns the `GameSession` plus the real-time orchestration the pure engine
/// stays out of: the gravity tick, the **lock delay** (a grace period after a
/// piece lands, during which you can still slide/rotate it; resets on a
/// successful move, capped so you can't stall forever), haptics, pause, and
/// recording finished games to the `ProgressStore`.
///
/// The main "feel" knobs live here: `lockDelay`, `maxLockResets`, the DAS/ARR
/// button-repeat timings on the controls, and the gravity curve in `Gravity`.
@MainActor
@Observable
public final class BlocksViewModel {
    public private(set) var session: GameSession

    /// Grace period after a piece lands before it locks.
    public var lockDelay: Duration = .milliseconds(500)
    /// How many times a move may reset the lock delay before it locks anyway.
    public var maxLockResets = 15
    /// Toggled from settings; gates all haptic feedback.
    public var hapticsEnabled = true

    private let progressStore: any ProgressStore
    private var gravityTask: Task<Void, Never>?
    private var lockTask: Task<Void, Never>?
    private var lockResets = 0
    private var gameStartDate = Date()
    private var recordedGameOver = false

    public init(
        session: GameSession = GameSession(),
        progressStore: any ProgressStore = UserDefaultsProgressStore()
    ) {
        self.session = session
        self.progressStore = progressStore
    }

    // MARK: - Lifecycle

    public func startIfNeeded() {
        guard session.status == .ready else { return }
        gameStartDate = Date()
        recordedGameOver = false
        session.start()
        startGravity()
        evaluateLock()
    }

    /// Discard the current game and start a fresh one with a new piece order.
    public func newGame() {
        teardown()
        session = GameSession(seed: UInt64(Date().timeIntervalSince1970 * 1000))
        gameStartDate = Date()
        recordedGameOver = false
        lockResets = 0
        session.start()
        startGravity()
        evaluateLock()
    }

    public func togglePause() {
        guard session.status == .playing || session.status == .paused else { return }
        session.togglePause()
        if session.status == .playing {
            startGravity()
            evaluateLock()
        } else {
            cancelLock()
        }
    }

    /// Stop all timers (call when the view goes away).
    public func teardown() {
        gravityTask?.cancel(); gravityTask = nil
        cancelLock()
    }

    // MARK: - Input

    @discardableResult
    public func input(_ move: Move) -> Bool {
        switch move {
        case .hardDrop:
            cancelLock()
            let clears = session.clearEventID
            let bursts = session.celebrationEventID
            session.apply(.hardDrop)
            feedbackForLock(clearsBefore: clears, burstsBefore: bursts)
            lockResets = 0
            evaluateLock()
            return true
        case .hold:
            let changed = session.apply(.hold)
            if changed { cancelLock(); lockResets = 0; evaluateLock() }
            return changed
        case .flip:
            let changed = session.apply(.flip)
            if changed { if hapticsEnabled { Haptics.play(.flip) }; afterPlayerMove() }
            return changed
        default:
            let changed = session.apply(move)
            if changed { afterPlayerMove() }
            return changed
        }
    }

    /// Park/swap the current pentomino against reserve slot `slot`.
    public func toggleHold(slot: Int) {
        guard session.status == .playing else { return }
        if session.toggleHold(slot: slot) {
            cancelLock()
            lockResets = 0
            evaluateLock()
        }
    }

    /// Detonate all resting bombs (Boom button).
    public func detonate() {
        guard session.status == .playing, session.bombsOnBoard > 0 else { return }
        let cleared = session.detonateBombs()
        if cleared > 0 {
            if hapticsEnabled { Haptics.play(.blocksOut) }
            // The board collapsed under the active piece — re-evaluate the lock.
            evaluateLock()
        }
    }

    /// Detonate all resting superbombs (BIG BOOM button).
    public func detonateSuperbombs() {
        guard session.status == .playing, session.hasSuperbombOnBoard else { return }
        let cleared = session.detonateSuperbombs()
        if cleared > 0 {
            if hapticsEnabled { Haptics.play(.blocksOut) }
            evaluateLock()
        }
    }

    public func queueBoost(_ boost: Boost) {
        session.queueBoost(boost)
    }

    // MARK: - Gravity

    private func startGravity() {
        gravityTask?.cancel()
        gravityTask = Task { [weak self] in
            while let self, self.session.status == .playing {
                let interval = Gravity.interval(forLevel: self.session.scoring.level)
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled, self.session.status == .playing else { return }
                self.gravityTick()
            }
        }
    }

    private func gravityTick() {
        session.gravityStep()
        evaluateLock()
    }

    // MARK: - Lock delay

    private func evaluateLock() {
        if session.status == .gameOver { handleGameOver(); return }
        guard session.status == .playing else { cancelLock(); return }
        if session.isGrounded {
            if lockTask == nil { scheduleLock() }
        } else {
            cancelLock()
            lockResets = 0
        }
    }

    private func afterPlayerMove() {
        guard session.status == .playing else { return }
        if session.isGrounded {
            if lockTask == nil {
                scheduleLock()
            } else if lockResets < maxLockResets {
                lockResets += 1
                scheduleLock()
            }
            // else: cap reached — let the running timer expire.
        } else {
            cancelLock()
            lockResets = 0
        }
    }

    private func scheduleLock() {
        lockTask?.cancel()
        lockTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.lockDelay)
            guard !Task.isCancelled else { return }
            self.commitLock()
        }
    }

    private func commitLock() {
        lockTask = nil
        guard session.status == .playing, session.isGrounded else { return }
        let clears = session.clearEventID
        let bursts = session.celebrationEventID
        session.lockActive()
        feedbackForLock(clearsBefore: clears, burstsBefore: bursts)
        lockResets = 0
        evaluateLock()
    }

    private func cancelLock() {
        lockTask?.cancel()
        lockTask = nil
    }

    // MARK: - Feedback + game over

    private func feedbackForLock(clearsBefore: Int, burstsBefore: Int) {
        guard hapticsEnabled else { return }
        if session.celebrationEventID > burstsBefore {
            Haptics.play(.blocksOut)
        } else if session.clearEventID > clearsBefore {
            Haptics.play(.lineClear)
        } else {
            Haptics.play(.lock)
        }
    }

    private func handleGameOver() {
        cancelLock()
        gravityTask?.cancel(); gravityTask = nil
        guard !recordedGameOver else { return }
        recordedGameOver = true
        if hapticsEnabled { Haptics.play(.gameOver) }
        let game = CompletedGame(
            score: session.scoring.score,
            linesCleared: session.scoring.linesCleared,
            level: session.scoring.level,
            duration: Date().timeIntervalSince(gameStartDate)
        )
        let store = progressStore
        Task { await store.record(game) }
    }
}
