import Foundation

/// Line-clear scoring. Because pieces are five cells and the well is wide,
/// clearing rows is harder than in Tetris — so multi-line clears are rewarded
/// steeply, with a five-row clear ("Blocks-Out") as the prestige event.
public struct Scoring: Sendable, Codable {
    public private(set) var score: Int = 0
    public private(set) var linesCleared: Int = 0
    /// Consecutive piece-locks that cleared at least one line.
    public private(set) var combo: Int = 0
    /// Whether the previous clear was a "difficult" one (4+ rows), enabling a
    /// back-to-back bonus on the next difficult clear.
    public private(set) var backToBackActive: Bool = false

    public init() {}

    /// Base points per simultaneous rows cleared (index = row count).
    private static let base = [0, 100, 300, 600, 1000, 1800]

    public var level: Int { Gravity.level(forLinesCleared: linesCleared) }

    /// Apply a single piece-lock result. `rows` is how many rows it cleared.
    public mutating func registerLock(rowsCleared rows: Int) {
        guard rows > 0 else {
            combo = 0
            return
        }

        let levelMultiplier = level + 1
        var points = Scoring.base[min(rows, 5)] * levelMultiplier

        // Back-to-back bonus for chained difficult clears (4+ rows).
        let isDifficult = rows >= 4
        if isDifficult && backToBackActive {
            points += points / 2
        }

        // Combo bonus grows with the streak.
        if combo > 0 {
            points += 50 * combo * levelMultiplier
        }

        score += points
        linesCleared += rows
        combo += 1
        backToBackActive = isDifficult
    }

    /// Soft/hard-drop bonus: a point per cell dropped.
    public mutating func addDropBonus(cells: Int) {
        score += max(0, cells)
    }
}
