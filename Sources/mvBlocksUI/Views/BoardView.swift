import SwiftUI
import mvBlocksKit

/// The playfield: glossy blocks (BlockGloss shader), a ghost landing preview,
/// animated line-clear and celebration overlays, and touch gestures.
///
/// Gestures: horizontal drag moves the piece, a tap rotates it, a long-press
/// flips it, and a downward flick hard-drops.
struct BoardView: View {
    @Environment(\.blocksTheme) private var theme
    @AppStorage(BlocksSettingsKey.ghostEnabled) private var ghostEnabled = BlocksSettingsDefault.ghostEnabled
    let vm: BlocksViewModel

    private var session: GameSession { vm.session }

    @State private var appliedX = 0
    @State private var flash: ClearFlash?
    @State private var burst: Burst?

    private struct ClearFlash: Equatable { var rows: [Int]; var start: Date }
    private struct Burst: Equatable { var seed: Double; var start: Date }

    private static let flashDuration = 0.35
    private static let burstDuration = 0.9

    var body: some View {
        let board = session.board
        let cols = board.width
        let rows = board.height

        GeometryReader { geo in
            let cell = min(geo.size.width / CGFloat(cols), geo.size.height / CGFloat(rows))
            let boardW = cell * CGFloat(cols)
            let boardH = cell * CGFloat(rows)
            let originX = (geo.size.width - boardW) / 2

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: cell * 0.3, style: .continuous)
                    .fill(theme.boardBackground)
                    .frame(width: boardW, height: boardH)
                    .offset(x: originX)

                // Ghost — where the active piece will land.
                if ghostEnabled, let ghost = session.ghost {
                    ForEach(cellsOf(ghost), id: \.id) { item in
                        GhostCell(color: theme.ghost, size: cell)
                            .offset(x: originX + CGFloat(item.x) * cell, y: CGFloat(item.y) * cell)
                    }
                }

                // Settled blocks.
                ForEach(settledCells(board), id: \.id) { item in
                    GlossyCell(color: item.color, size: cell)
                        .offset(x: originX + CGFloat(item.x) * cell, y: CGFloat(item.y) * cell)
                }

                // Active piece.
                if let active = session.active {
                    ForEach(cellsOf(active), id: \.id) { item in
                        GlossyCell(color: theme.color(for: active.kind), size: cell)
                            .offset(x: originX + CGFloat(item.x) * cell, y: CGFloat(item.y) * cell)
                    }
                }

                lineClearOverlay(cell: cell, originX: originX, cols: cols)
                celebrationOverlay(width: boardW, height: boardH, originX: originX)
            }
            .frame(width: geo.size.width, height: boardH, alignment: .topLeading)
            .contentShape(Rectangle())
            .gesture(dragGesture(cell: cell))
            .onTapGesture { vm.input(.rotateCW) }
            .onLongPressGesture(minimumDuration: 0.3) { vm.input(.flip) }
        }
        .aspectRatio(CGFloat(cols) / CGFloat(rows), contentMode: .fit)
        .overlay(alignment: .topTrailing) {
            if session.status == .playing || session.status == .paused {
                Button { vm.togglePause() } label: {
                    Image(systemName: session.status == .paused ? "play.fill" : "pause.fill")
                        .font(.headline)
                        .frame(width: 38, height: 38)
                        .background(.ultraThinMaterial, in: Circle())
                        .foregroundStyle(theme.headlineColor)
                }
                .padding(10)
            }
        }
        .overlay(alignment: .center) {
            if session.status == .paused {
                overlayCard(title: "Paused", button: "Resume") { vm.togglePause() }
            } else if session.status == .gameOver {
                overlayCard(title: "Game Over", subtitle: "Score \(session.scoring.score)", button: "New Game") {
                    vm.newGame()
                }
            }
        }
        .onChange(of: session.clearEventID) { _, _ in triggerFlash() }
        .onChange(of: session.celebrationEventID) { _, _ in triggerBurst() }
        .onChange(of: session.detonationEventID) { _, _ in triggerBurst() }
    }

    private func overlayCard(title: String, subtitle: String? = nil, button: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.title.bold())
                .foregroundStyle(theme.headlineColor)
            if let subtitle {
                Text(subtitle)
                    .font(.headline)
                    .foregroundStyle(theme.bodyColor)
            }
            Button(action: action) {
                Text(button)
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .frame(height: 44)
                    .background(theme.boostColor, in: Capsule())
                    .foregroundStyle(theme.pageBackground)
            }
        }
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Cell collections

    private struct CellItem: Identifiable { let id: Int; let x: Int; let y: Int; let color: Color }

    private func settledCells(_ board: BoardGrid) -> [CellItem] {
        var items: [CellItem] = []
        for y in 0..<board.height {
            for x in 0..<board.width {
                if let kind = board.cells[y][x] {
                    items.append(CellItem(id: y * board.width + x, x: x, y: y, color: theme.color(for: kind)))
                }
            }
        }
        return items
    }

    private func cellsOf(_ piece: ActivePiece) -> [CellItem] {
        piece.absoluteCells.enumerated().compactMap { idx, c in
            c.y >= 0 ? CellItem(id: idx, x: c.x, y: c.y, color: .clear) : nil
        }
    }

    // MARK: - Overlays

    @ViewBuilder
    private func lineClearOverlay(cell: CGFloat, originX: CGFloat, cols: Int) -> some View {
        if let flash {
            TimelineView(.animation) { tl in
                let progress = min(1, tl.date.timeIntervalSince(flash.start) / Self.flashDuration)
                ForEach(flash.rows, id: \.self) { y in
                    Rectangle()
                        .fill(Color.white.opacity(0.001))
                        .frame(width: cell * CGFloat(cols), height: cell)
                        .colorEffect(
                            ShaderLibrary.bundle(.module).lineClear(
                                .float2(cell * CGFloat(cols), cell),
                                .float(Float(progress))
                            )
                        )
                        .blendMode(.screen)
                        .offset(x: originX, y: cell * CGFloat(y))
                }
            }
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func celebrationOverlay(width: CGFloat, height: CGFloat, originX: CGFloat) -> some View {
        if let burst {
            TimelineView(.animation) { tl in
                let progress = min(1, tl.date.timeIntervalSince(burst.start) / Self.burstDuration)
                Rectangle()
                    .fill(Color.white.opacity(0.001))
                    .frame(width: width, height: height)
                    .colorEffect(
                        ShaderLibrary.bundle(.module).celebration(
                            .float2(width, height),
                            .float(Float(progress)),
                            .float(Float(burst.seed))
                        )
                    )
                    .blendMode(.screen)
                    .compositingGroup()
                    .offset(x: originX)
            }
            .allowsHitTesting(false)
        }
    }

    private func triggerFlash() {
        let rows = session.lastClearedRows
        guard !rows.isEmpty else { return }
        flash = ClearFlash(rows: rows, start: Date())
        Task {
            try? await Task.sleep(nanoseconds: UInt64(Self.flashDuration * 1_000_000_000))
            flash = nil
        }
    }

    private func triggerBurst() {
        burst = Burst(seed: Double(session.celebrationEventID) * 0.371, start: Date())
        Task {
            try? await Task.sleep(nanoseconds: UInt64(Self.burstDuration * 1_000_000_000))
            burst = nil
        }
    }

    // MARK: - Gestures

    private func dragGesture(cell: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let target = Int((value.translation.width / cell).rounded(.toNearestOrAwayFromZero))
                while appliedX < target, vm.input(.right) { appliedX += 1 }
                while appliedX > target, vm.input(.left) { appliedX -= 1 }
            }
            .onEnded { value in
                let t = value.translation
                let predicted = value.predictedEndTranslation
                let verticalIntent = abs(t.height) > abs(t.width)
                let isDownFlick = verticalIntent && t.height > cell && predicted.height > t.height * 1.4
                let isUpFlick = verticalIntent && t.height < -cell && predicted.height < t.height * 1.4
                if isDownFlick { vm.input(.hardDrop) }
                else if isUpFlick { vm.input(.hold) }
                appliedX = 0
            }
    }
}

/// A single block rendered with the BlockGloss Metal shader.
struct GlossyCell: View {
    let color: Color
    let size: CGFloat

    var body: some View {
        let gap = max(1, size * 0.06)
        let inner = size - gap * 2
        RoundedRectangle(cornerRadius: inner * 0.22, style: .continuous)
            .fill(color)
            .frame(width: inner, height: inner)
            .colorEffect(ShaderLibrary.bundle(.module).blockGloss(.float2(inner, inner)))
            .offset(x: gap, y: gap)
    }
}

/// The translucent landing preview — no shader.
struct GhostCell: View {
    let color: Color
    let size: CGFloat

    var body: some View {
        let gap = max(1, size * 0.06)
        let inner = size - gap * 2
        RoundedRectangle(cornerRadius: inner * 0.22, style: .continuous)
            .strokeBorder(color, lineWidth: max(1, size * 0.08))
            .frame(width: inner, height: inner)
            .offset(x: gap, y: gap)
    }
}
