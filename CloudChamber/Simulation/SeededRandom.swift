import Foundation

/// Small deterministic SplitMix64 generator so tests and screenshots are reproducible.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    mutating func unit() -> Double {
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }

    mutating func uniform(_ lower: Double, _ upper: Double) -> Double {
        guard upper > lower else { return lower }
        return lower + (upper - lower) * unit()
    }

    mutating func chance(_ probability: Double) -> Bool {
        unit() < min(max(probability, 0), 1)
    }

    mutating func gaussian() -> Double {
        let u1 = max(unit(), 0.000_000_000_1)
        let u2 = unit()
        return sqrt(-2 * log(u1)) * cos(2 * Double.pi * u2)
    }

    mutating func integer(in range: ClosedRange<Int>) -> Int {
        guard range.upperBound > range.lowerBound else { return range.lowerBound }
        let width = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % width)
    }
}
