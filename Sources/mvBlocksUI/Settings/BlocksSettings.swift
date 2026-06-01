import Foundation

/// `@AppStorage` keys for player-facing settings. One constant per knob keeps
/// spellings consistent between the views that read them and the settings sheet
/// that writes them.
public enum BlocksSettingsKey {
    public static let themeName = "dev.scalecode.mvBlocks.themeName"
    public static let ghostEnabled = "dev.scalecode.mvBlocks.ghostEnabled"
    public static let hapticsEnabled = "dev.scalecode.mvBlocks.hapticsEnabled"
}

/// Default values, kept alongside the keys so the settings layer is the single
/// source of truth.
public enum BlocksSettingsDefault {
    public static let themeName = BlocksThemeName.neonNursery.rawValue
    public static let ghostEnabled = true
    public static let hapticsEnabled = true
}
