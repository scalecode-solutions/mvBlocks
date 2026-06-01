# mvBlocks

A Swift Package for **Blocks** — a falling-block stacker built on the twelve
**pentominoes** (five-cell pieces), not the usual tetrominoes. Where Tetris
trims polyominoes down to four cells and seven pieces, Blocks goes the other
way: bigger pieces, a wider well, and a **flip** control that lets you mirror
chiral pieces by hand. Built for iOS 26 with SwiftUI 6 and Metal shaders.

Two products: a pure-Swift engine (`mvBlocksKit`) and a SwiftUI view layer
(`mvBlocksUI`).

> Drop `BlocksGameView()` into any SwiftUI app and you've got the game —
> board, ghost piece, hold + next queue, and the controls to play. Themeable.

## Why pentominoes

Alexey Pajitnov's original inspiration for Tetris *was* pentominoes; he cut
them to four cells to make the game tractable on a text terminal in 1984.
Blocks runs the experiment he didn't: all **12 free pentominoes**
(`F I L N P T U V W X Y Z`), 63 distinct fixed orientations, a flip mechanic
for the six chiral pieces, and a 12-wide well to fit them. The piece set, the
colors, the board, and the rotation system are all our own — no Tetris trade
dress.

## Requirements

- iOS 26 (iPhone)
- Xcode 26 / Swift 6.2+

(Also builds on macOS 26 so `swift test` runs locally; the UI targets iPhone.)

## Install

```swift
dependencies: [
    .package(url: "https://github.com/scalecode-solutions/mvBlocks.git", from: "0.1.0"),
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "mvBlocksUI", package: "mvBlocks"),
            // engine-only:
            // .product(name: "mvBlocksKit", package: "mvBlocks"),
        ]
    )
]
```

## Quick start

```swift
import SwiftUI
import mvBlocksUI

struct ContentView: View {
    var body: some View {
        BlocksGameView()
            .blocksTheme(.neonNursery)
    }
}
```

## Status

**v0.1 — feature-complete and playable.**

- **Engine** (`mvBlocksKit`): all 12 pentominoes (63 orientations), the flip
  mechanic, 12-bag randomizer, gravity, scoring (combo + back-to-back +
  five-row "Blocks-Out"), boost blocks, and a `ProgressStore` (UserDefaults +
  SwiftData).
- **UI** (`mvBlocksUI`): themeable SwiftUI views with Metal shaders (block
  gloss, line-clear flash, celebration burst), ghost piece, next + hold panels,
  gesture and DAS/ARR button controls, lock delay, pause, and settings + stats
  sheets.
- **Demo** (`Demo/mvBlocksDemo`): runs standalone. See `EMBEDDING.md` for host
  integration.

Covered by Swift Testing (engine + view-model). Next: feel-tuning and host
integration.
