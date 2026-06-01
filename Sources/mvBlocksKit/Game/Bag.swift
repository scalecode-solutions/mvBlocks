import Foundation

/// A small, deterministic PRNG so the bag (and tests) are reproducible from a
/// seed without depending on the system RNG. SplitMix64.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// The "12-bag" randomizer: shuffle all twelve pentominoes, deal them out, then
/// reshuffle — so every piece appears once per cycle and droughts are bounded.
public struct Bag: Sendable {
    private var rng: SeededGenerator
    private var queue: [Pentomino] = []

    public init(seed: UInt64) {
        self.rng = SeededGenerator(seed: seed)
        refill()
    }

    private mutating func refill() {
        queue = Pentomino.allCases.shuffled(using: &rng)
    }

    /// Draw the next piece, refilling the bag when it empties.
    public mutating func next() -> Pentomino {
        if queue.isEmpty { refill() }
        return queue.removeFirst()
    }

    /// Peek the next `count` pieces (for the preview queue) without consuming
    /// them or advancing the bag. Simulates refills on a copy of the state, so
    /// the result matches the order `next()` will actually deal.
    public func peek(_ count: Int) -> [Pentomino] {
        var lookahead = queue
        var generator = rng
        while lookahead.count < count {
            lookahead.append(contentsOf: Pentomino.allCases.shuffled(using: &generator))
        }
        return Array(lookahead.prefix(count))
    }
}
