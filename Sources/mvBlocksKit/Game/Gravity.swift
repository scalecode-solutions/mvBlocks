import Foundation

/// Maps the current level to a gravity interval — the seconds between automatic
/// one-cell drops. Speeds up per level and floors out so the top levels stay
/// humanly playable. Tuned by feel in the Demo app.
public enum Gravity {
    /// Seconds the active piece rests on a row before auto-dropping one cell.
    public static func interval(forLevel level: Int) -> TimeInterval {
        let clamped = max(0, level)
        // Classic-style geometric curve: ~0.8s at level 0 down to a 0.05s floor.
        let raw = 0.80 * pow(0.85, Double(clamped))
        return max(0.05, raw)
    }

    /// Lines cleared to advance a level.
    public static let linesPerLevel = 10

    public static func level(forLinesCleared lines: Int) -> Int {
        max(0, lines) / linesPerLevel
    }
}
