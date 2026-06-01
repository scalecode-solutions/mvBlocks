import SwiftUI
import mvBlocksKit

/// Aggregate stats + recent-game history from a ``ProgressStore``. Reloads each
/// time it's presented.
public struct StatsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.blocksTheme) private var theme

    public let store: any ProgressStore

    @State private var summary: StatsSummary = .empty
    @State private var recent: [CompletedGame] = []
    @State private var isLoading = true

    public init(store: any ProgressStore) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    summarySection
                    historySection
                }
                .padding(20)
            }
            .background(theme.pageBackground.ignoresSafeArea())
            .navigationTitle("Stats")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset", role: .destructive) {
                        Task { await store.reset(); await load() }
                    }
                    .foregroundStyle(theme.bodyColor)
                    .disabled(summary.gamesPlayed == 0)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(theme.headlineColor)
                }
            }
            #endif
        }
        .task { await load() }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Summary")
            HStack(spacing: 10) {
                statCard(value: "\(summary.gamesPlayed)", label: "Games")
                statCard(value: "\(summary.highScore)", label: "High Score")
                statCard(value: "\(summary.totalLines)", label: "Lines")
                statCard(value: "\(summary.bestLevel)", label: "Best Lv")
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Recent Games")
            if isLoading && recent.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else if recent.isEmpty {
                ContentUnavailableView(
                    "No games yet",
                    systemImage: "square.grid.3x3",
                    description: Text("Play a round to start tracking stats.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                VStack(spacing: 8) {
                    ForEach(recent) { game in
                        gameRow(game)
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(theme.bodyColor.opacity(0.9))
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.heavy))
                .foregroundStyle(theme.headlineColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(label)
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(theme.bodyColor.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(theme.bodyColor.opacity(0.18), lineWidth: 1)
                )
        )
    }

    private func gameRow(_ game: CompletedGame) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.title3)
                .foregroundStyle(theme.boostColor)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(game.score) pts")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.headlineColor)
                Text("\(game.linesCleared) lines · Lv \(game.level)")
                    .font(.caption)
                    .foregroundStyle(theme.bodyColor.opacity(0.75))
            }
            Spacer()
            Text(game.date, format: .relative(presentation: .named))
                .font(.caption)
                .foregroundStyle(theme.bodyColor.opacity(0.55))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    private func load() async {
        async let summaryFetch = store.summary()
        async let recentFetch = store.history(limit: 25)
        self.summary = await summaryFetch
        self.recent = await recentFetch
        self.isLoading = false
    }
}
