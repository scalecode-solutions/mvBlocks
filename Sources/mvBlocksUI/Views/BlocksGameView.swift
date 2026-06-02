import SwiftUI
import mvBlocksKit

/// The Blocks game surface. Ships in standalone (`embedded: false`) and
/// host-embedded (`embedded: true`) modes — see EMBEDDING.md.
public struct BlocksGameView: View {
    @AppStorage(BlocksSettingsKey.themeName) private var themeName = BlocksSettingsDefault.themeName
    @AppStorage(BlocksSettingsKey.hapticsEnabled) private var hapticsEnabled = BlocksSettingsDefault.hapticsEnabled

    @State private var vm: BlocksViewModel
    @State private var internalShowStats = false
    @State private var internalShowSettings = false

    private let progressStore: any ProgressStore
    private let embedded: Bool
    private let isShowingStats: Binding<Bool>?
    private let isShowingSettings: Binding<Bool>?

    public init(
        session: GameSession? = nil,
        progressStore: any ProgressStore = UserDefaultsProgressStore(),
        embedded: Bool = false,
        isShowingStats: Binding<Bool>? = nil,
        isShowingSettings: Binding<Bool>? = nil
    ) {
        _vm = State(initialValue: BlocksViewModel(
            session: session ?? GameSession(),
            progressStore: progressStore
        ))
        self.progressStore = progressStore
        self.embedded = embedded
        self.isShowingStats = isShowingStats
        self.isShowingSettings = isShowingSettings
    }

    private var theme: Theme {
        BlocksThemeName(rawValue: themeName)?.theme ?? .neonNursery
    }

    public var body: some View {
        let statsBinding = isShowingStats ?? $internalShowStats
        let settingsBinding = isShowingSettings ?? $internalShowSettings

        return VStack(spacing: 14) {
            if !embedded {
                header
            }
            topPanels
            BoardView(vm: vm)
            boostBar
            controlBar
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.pageBackground.ignoresSafeArea())
        .environment(\.blocksTheme, theme)
        .onAppear {
            vm.hapticsEnabled = hapticsEnabled
            vm.startIfNeeded()
        }
        .onChange(of: hapticsEnabled) { _, new in vm.hapticsEnabled = new }
        .onDisappear { vm.teardown() }
        .sheet(isPresented: statsBinding) {
            StatsSheet(store: progressStore).blocksTheme(theme)
        }
        .sheet(isPresented: settingsBinding) {
            SettingsSheet().blocksTheme(theme)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            Text("Blocks")
                .font(.title2.bold())
                .foregroundStyle(theme.headlineColor)
            Spacer()
            Text("Score \(vm.session.scoring.score)")
                .font(.headline)
                .foregroundStyle(theme.bodyColor)
            Button { internalShowStats = true } label: {
                Image(systemName: "chart.bar.fill")
            }
            .foregroundStyle(theme.bodyColor)
            Button { internalShowSettings = true } label: {
                Image(systemName: "gearshape.fill")
            }
            .foregroundStyle(theme.bodyColor)
        }
    }

    // MARK: - Hold + Next

    private var topPanels: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("HOLD")
                    .font(.caption2.bold())
                    .foregroundStyle(theme.bodyColor)
                HStack(spacing: 6) { holdSlot(0); holdSlot(1) }
            }
            Divider().frame(height: 46).overlay(theme.gridLines)
            nextQueue
            Spacer()
        }
        .frame(height: 50)
    }

    /// A reserve slot: tap empty to park the current piece, tap filled to swap.
    private func holdSlot(_ index: Int) -> some View {
        Button { vm.toggleHold(slot: index) } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(theme.boardBackground)
                    .frame(width: 44, height: 30)
                if let held = vm.session.holds[index] {
                    piecePreview(.pentomino(held), cell: 6)
                } else {
                    Image(systemName: "plus").font(.caption).foregroundStyle(theme.bodyColor.opacity(0.5))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var nextQueue: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("NEXT")
                .font(.caption2.bold())
                .foregroundStyle(theme.bodyColor)
            HStack(alignment: .center, spacing: 10) {
                ForEach(Array(vm.session.nextQueue(4).enumerated()), id: \.offset) { _, piece in
                    piecePreview(.pentomino(piece), cell: 7)
                }
            }
            .frame(height: 30)
        }
    }

    /// A tiny canvas drawing of a piece, sized to its bounding box.
    private func piecePreview(_ kind: PieceKind, cell: CGFloat) -> some View {
        let orientation = kind.orientations[0]
        let w = CGFloat(orientation.width)
        let h = CGFloat(orientation.height)
        let color = theme.color(for: kind)
        return Canvas { context, _ in
            for c in orientation.cells {
                let rect = CGRect(x: CGFloat(c.x) * cell + 1,
                                  y: CGFloat(c.y) * cell + 1,
                                  width: cell - 2, height: cell - 2)
                context.fill(Path(roundedRect: rect, cornerRadius: cell * 0.2), with: .color(color))
            }
        }
        .frame(width: w * cell, height: h * cell)
    }

    // MARK: - Boosts

    private var boostBar: some View {
        HStack(spacing: 8) {
            boostButton(.single)
            boostButton(.bomb)
            // Superbomb arm appears only once you've earned one.
            if (vm.session.boosts[.superbomb] ?? 0) > 0 { boostButton(.superbomb) }
            Spacer()
            boomButton
            // BIG BOOM appears only when a superbomb is on the board.
            if vm.session.hasSuperbombOnBoard { bigBoomButton }
        }
    }

    /// Detonate all resting superbombs (6×6 + their rows/cols).
    private var bigBoomButton: some View {
        Button { vm.detonateSuperbombs() } label: {
            HStack(spacing: 5) {
                Image(systemName: "burst.fill")
                Text("BIG BOOM")
            }
            .font(.subheadline.bold())
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(theme.superbombColor, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.white)
        }
        .disabled(vm.session.status != .playing)
    }

    /// Detonate all resting bombs (each clears its row + column).
    private var boomButton: some View {
        let live = vm.session.bombsOnBoard
        return Button { vm.detonate() } label: {
            HStack(spacing: 5) {
                Image(systemName: "flame.fill")
                Text("BOOM")
            }
            .font(.subheadline.bold())
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(live > 0 ? theme.bombColor : theme.boardBackground,
                        in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(live > 0 ? .white : theme.bodyColor.opacity(0.4))
        }
        .disabled(live == 0 || vm.session.status != .playing)
    }

    private func boostButton(_ boost: Boost) -> some View {
        let count = vm.session.boosts[boost] ?? 0
        let armed = vm.session.queuedBoost != nil
        return Button {
            vm.queueBoost(boost)
        } label: {
            HStack(spacing: 8) {
                // Draw the actual shape (1 cell vs 2 stacked cells) so the
                // domino reads as two squares, not one big block.
                piecePreview(.boost(boost), cell: 9)
                    .opacity(count > 0 ? 1 : 0.4)
                Text("×\(count)")
                    .font(.subheadline.monospacedDigit())
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(theme.boardBackground, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(count > 0 ? theme.boostColor : theme.bodyColor.opacity(0.4))
        }
        .disabled(count == 0 || armed || vm.session.status != .playing)
    }

    // MARK: - Controls

    private var controlBar: some View {
        HStack(spacing: 10) {
            HoldRepeatButton(symbol: "arrow.left") { vm.input(.left) }
            controlButton("arrow.clockwise") { vm.input(.rotateCW) }
            controlButton("arrow.left.and.right.righttriangle.left.righttriangle.right") {
                vm.input(.flip)
            }
            HoldRepeatButton(symbol: "arrow.right") { vm.input(.right) }
            controlButton("arrow.down.to.line") { vm.input(.hardDrop) }
        }
        .disabled(vm.session.status != .playing)
    }

    private func controlButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 52, height: 52)
                .background(theme.boardBackground, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(theme.headlineColor)
        }
    }
}

/// A control button that fires once on press, then auto-repeats after a short
/// delay (DAS) at a fast rate (ARR) while held — the standard feel for moving
/// a piece sideways by holding the button.
struct HoldRepeatButton: View {
    @Environment(\.blocksTheme) private var theme

    let symbol: String
    var das: Duration = .milliseconds(170)
    var arr: Duration = .milliseconds(45)
    let action: () -> Void

    @State private var repeatTask: Task<Void, Never>?

    var body: some View {
        Image(systemName: symbol)
            .font(.title3)
            .frame(width: 52, height: 52)
            .background(theme.boardBackground, in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(theme.headlineColor)
            .contentShape(RoundedRectangle(cornerRadius: 14))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if repeatTask == nil { startRepeating() } }
                    .onEnded { _ in stopRepeating() }
            )
    }

    private func startRepeating() {
        action()
        repeatTask = Task { @MainActor in
            try? await Task.sleep(for: das)
            while !Task.isCancelled {
                action()
                try? await Task.sleep(for: arr)
            }
        }
    }

    private func stopRepeating() {
        repeatTask?.cancel()
        repeatTask = nil
    }
}
