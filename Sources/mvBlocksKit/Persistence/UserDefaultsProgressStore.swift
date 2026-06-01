import Foundation

/// Lightweight `ProgressStore` backed by `UserDefaults` — the default store and
/// a drop-in for hosts that don't want a SwiftData container.
public actor UserDefaultsProgressStore: ProgressStore {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "mvBlocks.history") {
        self.defaults = defaults
        self.key = key
    }

    private func load() -> [CompletedGame] {
        guard let data = defaults.data(forKey: key),
              let games = try? JSONDecoder().decode([CompletedGame].self, from: data)
        else { return [] }
        return games
    }

    private func save(_ games: [CompletedGame]) {
        guard let data = try? JSONEncoder().encode(games) else { return }
        defaults.set(data, forKey: key)
    }

    public func record(_ game: CompletedGame) async {
        var games = load()
        games.append(game)
        save(games)
    }

    public func summary() async -> StatsSummary {
        let games = load()
        guard !games.isEmpty else { return .empty }
        return StatsSummary(
            gamesPlayed: games.count,
            highScore: games.map(\.score).max() ?? 0,
            totalLines: games.map(\.linesCleared).reduce(0, +),
            bestLevel: games.map(\.level).max() ?? 0
        )
    }

    public func history(limit: Int) async -> [CompletedGame] {
        Array(load().sorted { $0.date > $1.date }.prefix(limit))
    }

    public func reset() async {
        defaults.removeObject(forKey: key)
    }
}
