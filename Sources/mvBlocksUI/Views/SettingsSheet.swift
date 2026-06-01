import SwiftUI
import mvBlocksKit

/// Settings: theme, ghost piece, and haptics. All `@AppStorage`-backed so they
/// persist and apply live.
public struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.blocksTheme) private var theme

    @AppStorage(BlocksSettingsKey.themeName) private var themeName = BlocksSettingsDefault.themeName
    @AppStorage(BlocksSettingsKey.ghostEnabled) private var ghostEnabled = BlocksSettingsDefault.ghostEnabled
    @AppStorage(BlocksSettingsKey.hapticsEnabled) private var hapticsEnabled = BlocksSettingsDefault.hapticsEnabled

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                Section("Theme") {
                    Picker("Theme", selection: $themeName) {
                        ForEach(BlocksThemeName.allCases) { name in
                            Text(name.label).tag(name.rawValue)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Gameplay") {
                    Toggle("Ghost Piece", isOn: $ghostEnabled)
                    Toggle("Haptics", isOn: $hapticsEnabled)
                }

                Section {
                    Text("Ghost shows where the active piece will land. Boosts (the single and double blocks) fill the gaps pentominoes leave behind — you start with five of each and earn more by clearing rows.")
                        .font(.footnote)
                        .foregroundStyle(theme.bodyColor)
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.pageBackground.ignoresSafeArea())
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(theme.headlineColor)
                }
            }
            #endif
        }
    }
}
