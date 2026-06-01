# Embedding BlocksGameView in a Host App

`BlocksGameView` ships in two modes. The default (`embedded: false`) owns the
whole screen and draws its own title row with the Stats and Settings buttons —
that's what `Demo/mvBlocksDemo` uses. The other mode is for slotting the game
*inside* an existing app shell (NavigationStack, TabView, sheet, anywhere with
its own chrome) — that's how Clingy's den hosts it.

## Standalone

```swift
import mvBlocksUI

struct ContentView: View {
    var body: some View {
        BlocksGameView()
            .blocksTheme(.neonNursery)
    }
}
```

Runs with the internal header (title + stats button + settings button).

## Embedded

Opt-in parameters mirror the other Scalecode game packages:

```swift
public init(
    session: GameSession? = nil,
    progressStore: any ProgressStore = UserDefaultsProgressStore(),
    embedded: Bool = false,
    isShowingStats: Binding<Bool>? = nil,
    isShowingSettings: Binding<Bool>? = nil
)
```

- **`embedded: true`** hides the internal title row. The host's nav bar is the
  only top chrome on screen; the themed page background still extends
  edge-to-edge underneath it.
- **`isShowingStats`** / **`isShowingSettings`** are optional external bindings
  for the sheets — wire your own toolbar items to them when the internal header
  is hidden.

```swift
import mvBlocksUI

struct BlocksDestination: View {
    @State private var showsStats = false
    @State private var showsSettings = false

    var body: some View {
        BlocksGameView(
            embedded: true,
            isShowingStats: $showsStats,
            isShowingSettings: $showsSettings
        )
        .navigationTitle("Blocks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showsStats = true } label: { Image(systemName: "chart.bar") }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showsSettings = true } label: { Image(systemName: "gearshape") }
            }
        }
    }
}
```
