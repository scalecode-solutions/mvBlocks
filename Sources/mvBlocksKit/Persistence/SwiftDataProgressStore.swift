import Foundation
import SwiftData

/// SwiftData-backed `ProgressStore` for hosts that want durable, queryable
/// history. The Demo app uses this; Clingy can supply its own container.
public actor SwiftDataProgressStore: ProgressStore {

    @Model
    final class GameRecord {
        var id: UUID
        var date: Date
        var score: Int
        var linesCleared: Int
        var level: Int
        var duration: TimeInterval

        init(from game: CompletedGame) {
            self.id = game.id
            self.date = game.date
            self.score = game.score
            self.linesCleared = game.linesCleared
            self.level = game.level
            self.duration = game.duration
        }

        var completed: CompletedGame {
            CompletedGame(
                id: id,
                date: date,
                score: score,
                linesCleared: linesCleared,
                level: level,
                duration: duration
            )
        }
    }

    private let container: ModelContainer

    public init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        self.container = try ModelContainer(for: GameRecord.self, configurations: config)
    }

    /// In-memory container for tests/previews.
    public init(inMemory: Bool) throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        self.container = try ModelContainer(for: GameRecord.self, configurations: config)
    }

    public func record(_ game: CompletedGame) async {
        let context = ModelContext(container)
        context.insert(GameRecord(from: game))
        try? context.save()
    }

    public func summary() async -> StatsSummary {
        let games = await allRecords()
        guard !games.isEmpty else { return .empty }
        return StatsSummary(
            gamesPlayed: games.count,
            highScore: games.map(\.score).max() ?? 0,
            totalLines: games.map(\.linesCleared).reduce(0, +),
            bestLevel: games.map(\.level).max() ?? 0
        )
    }

    public func history(limit: Int) async -> [CompletedGame] {
        Array(await allRecords().sorted { $0.date > $1.date }.prefix(limit))
    }

    public func reset() async {
        let context = ModelContext(container)
        try? context.delete(model: GameRecord.self)
        try? context.save()
    }

    private func allRecords() async -> [CompletedGame] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<GameRecord>()
        let records = (try? context.fetch(descriptor)) ?? []
        return records.map(\.completed)
    }
}
