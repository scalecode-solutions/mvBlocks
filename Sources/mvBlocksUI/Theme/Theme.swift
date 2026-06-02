import SwiftUI
import mvBlocksKit

/// Color palette + style knobs for the Blocks UI. Value type so it drops
/// straight into a SwiftUI Environment with no isolation concerns.
public struct Theme: Sendable {
    /// Behind everything.
    public var pageBackground: Color
    /// The well / board background.
    public var boardBackground: Color
    /// Grid line color.
    public var gridLines: Color
    /// The translucent landing-preview piece.
    public var ghost: Color
    /// Primary headline color (titles, score).
    public var headlineColor: Color
    /// Secondary body text.
    public var bodyColor: Color
    /// Fill for single (filler) boost blocks — a bright neutral.
    public var boostColor: Color
    /// Fill for bombs — hot red so they read as "danger / detonate me".
    public var bombColor: Color = Color(red: 0.96, green: 0.30, blue: 0.26)
    /// Fill for superbombs — electric violet, a tier above the red bomb.
    public var superbombColor: Color = Color(red: 0.70, green: 0.36, blue: 1.0)
    /// Per-pentomino fill colors. Must cover all twelve cases.
    public var pieceColors: [Pentomino: Color]

    public init(
        pageBackground: Color,
        boardBackground: Color,
        gridLines: Color,
        ghost: Color,
        headlineColor: Color,
        bodyColor: Color,
        boostColor: Color,
        pieceColors: [Pentomino: Color]
    ) {
        self.pageBackground = pageBackground
        self.boardBackground = boardBackground
        self.gridLines = gridLines
        self.ghost = ghost
        self.headlineColor = headlineColor
        self.bodyColor = bodyColor
        self.boostColor = boostColor
        self.pieceColors = pieceColors
    }

    /// Color for a pentomino, falling back to the headline color if unmapped.
    public func color(for piece: Pentomino) -> Color {
        pieceColors[piece] ?? headlineColor
    }

    /// Color for any placeable kind.
    public func color(for kind: PieceKind) -> Color {
        switch kind {
        case .pentomino(let p): color(for: p)
        case .boost(let b):
            switch b {
            case .bomb: bombColor
            case .superbomb: superbombColor
            case .single: boostColor
            }
        }
    }
}

extension Theme {
    /// Neon nursery: deep ink page, saturated piece palette, soft grid.
    /// Original colors — deliberately *not* the classic Tetris seven.
    public static let neonNursery = Theme(
        pageBackground: Color(red: 0.06, green: 0.06, blue: 0.10),
        boardBackground: Color(red: 0.10, green: 0.10, blue: 0.16),
        gridLines: Color.white.opacity(0.06),
        ghost: Color.white.opacity(0.18),
        headlineColor: Color(red: 0.96, green: 0.96, blue: 1.0),
        bodyColor: Color(red: 0.72, green: 0.74, blue: 0.86),
        boostColor: Color(red: 1.00, green: 0.98, blue: 0.86),
        pieceColors: [
            .f: Color(red: 1.00, green: 0.36, blue: 0.55),
            .i: Color(red: 0.30, green: 0.86, blue: 0.96),
            .l: Color(red: 1.00, green: 0.66, blue: 0.24),
            .n: Color(red: 0.62, green: 0.84, blue: 0.36),
            .p: Color(red: 0.96, green: 0.44, blue: 0.86),
            .t: Color(red: 0.66, green: 0.52, blue: 1.00),
            .u: Color(red: 0.36, green: 0.74, blue: 1.00),
            .v: Color(red: 0.98, green: 0.82, blue: 0.30),
            .w: Color(red: 0.42, green: 0.92, blue: 0.74),
            .x: Color(red: 1.00, green: 0.50, blue: 0.42),
            .y: Color(red: 0.80, green: 0.62, blue: 1.00),
            .z: Color(red: 0.52, green: 0.90, blue: 0.52),
        ]
    )

    /// Soft pastel daytime palette.
    public static let pastel = Theme(
        pageBackground: Color(red: 0.96, green: 0.95, blue: 0.98),
        boardBackground: Color(red: 1.00, green: 1.00, blue: 1.00),
        gridLines: Color.black.opacity(0.06),
        ghost: Color.black.opacity(0.10),
        headlineColor: Color(red: 0.20, green: 0.18, blue: 0.30),
        bodyColor: Color(red: 0.42, green: 0.40, blue: 0.52),
        boostColor: Color(red: 0.32, green: 0.30, blue: 0.42),
        pieceColors: [
            .f: Color(red: 0.96, green: 0.62, blue: 0.70),
            .i: Color(red: 0.62, green: 0.84, blue: 0.90),
            .l: Color(red: 0.98, green: 0.80, blue: 0.58),
            .n: Color(red: 0.74, green: 0.86, blue: 0.66),
            .p: Color(red: 0.94, green: 0.72, blue: 0.88),
            .t: Color(red: 0.78, green: 0.74, blue: 0.94),
            .u: Color(red: 0.68, green: 0.82, blue: 0.94),
            .v: Color(red: 0.96, green: 0.88, blue: 0.62),
            .w: Color(red: 0.70, green: 0.90, blue: 0.82),
            .x: Color(red: 0.96, green: 0.70, blue: 0.64),
            .y: Color(red: 0.84, green: 0.76, blue: 0.94),
            .z: Color(red: 0.74, green: 0.88, blue: 0.74),
        ]
    )
}

/// Named themes the user can pick from in Settings.
public enum BlocksThemeName: String, CaseIterable, Sendable, Hashable, Codable, Identifiable {
    case neonNursery
    case pastel

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .neonNursery: "Neon Nursery"
        case .pastel:      "Pastel"
        }
    }

    public var theme: Theme {
        switch self {
        case .neonNursery: .neonNursery
        case .pastel:      .pastel
        }
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: Theme = .neonNursery
}

extension EnvironmentValues {
    public var blocksTheme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

extension View {
    public func blocksTheme(_ theme: Theme) -> some View {
        environment(\.blocksTheme, theme)
    }
}
