import Foundation

/// A finished game of Blocks, suitable for stats aggregation.
public struct CompletedGame: Sendable, Hashable, Codable, Identifiable {
    public let id: UUID
    public let date: Date
    public let score: Int
    public let linesCleared: Int
    public let level: Int
    public let duration: TimeInterval

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        score: Int,
        linesCleared: Int,
        level: Int,
        duration: TimeInterval
    ) {
        self.id = id
        self.date = date
        self.score = score
        self.linesCleared = linesCleared
        self.level = level
        self.duration = duration
    }
}

/// Aggregate stats over many `CompletedGame`s.
public struct StatsSummary: Sendable, Hashable, Codable {
    public let gamesPlayed: Int
    public let highScore: Int
    public let totalLines: Int
    public let bestLevel: Int

    public static let empty = StatsSummary(
        gamesPlayed: 0,
        highScore: 0,
        totalLines: 0,
        bestLevel: 0
    )

    public init(gamesPlayed: Int, highScore: Int, totalLines: Int, bestLevel: Int) {
        self.gamesPlayed = gamesPlayed
        self.highScore = highScore
        self.totalLines = totalLines
        self.bestLevel = bestLevel
    }
}

/// Persistence backend for completed-game records.
public protocol ProgressStore: Sendable {
    func record(_ game: CompletedGame) async
    func summary() async -> StatsSummary
    func history(limit: Int) async -> [CompletedGame]
    func reset() async
}
