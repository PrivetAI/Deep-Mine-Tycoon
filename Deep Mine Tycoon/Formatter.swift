import Foundation

// Deterministic SplitMix64 PRNG — never use String.hashValue / Hasher().
struct DDMRandom {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed &+ 0x9E3779B97F4A7C15
    }

    mutating func nextUInt64() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    // Uniform Double in [0, 1).
    mutating func nextDouble() -> Double {
        let v = nextUInt64() >> 11 // 53 bits
        return Double(v) * (1.0 / 9007199254740992.0)
    }

    // Uniform Int in [lower, upper].
    mutating func nextInt(_ lower: Int, _ upper: Int) -> Int {
        if upper <= lower { return lower }
        let span = UInt64(upper - lower + 1)
        return lower + Int(nextUInt64() % span)
    }

    // Bool with given true-probability.
    mutating func chance(_ p: Double) -> Bool {
        return nextDouble() < p
    }
}

// Combine two integers into a deterministic seed without Hasher.
func ddmSeed(_ a: Int, _ b: Int) -> UInt64 {
    var x = UInt64(bitPattern: Int64(a)) &* 0x9E3779B97F4A7C15
    x ^= UInt64(bitPattern: Int64(b)) &+ 0xD1B54A32D192ED03
    x = (x ^ (x >> 29)) &* 0xBF58476D1CE4E5B9
    return x
}

// Big-number formatter: K / M / B / T then aa, ab, ac ...
enum DDMFormat {
    private static let smallSuffixes = ["", "K", "M", "B", "T"]

    static func number(_ value: Double) -> String {
        if !value.isFinite { return "0" }
        let v = max(0, value)
        if v < 1000 {
            // whole-ish numbers below 1000
            if v < 10 && v != v.rounded() {
                return String(format: "%.1f", v)
            }
            return String(Int(v.rounded()))
        }

        var tier = 0
        var n = v
        while n >= 1000 && tier < 4 {
            n /= 1000
            tier += 1
        }
        // If trim() would round n up to 1000 (e.g. 999.5 -> "1000"), advance to the next tier
        // to avoid displaying e.g. "1000K" instead of "1.00M".
        if n >= 999.5 && tier < 4 {
            n /= 1000
            tier += 1
        }
        if tier < smallSuffixes.count - 1 || (tier == smallSuffixes.count - 1 && n < 999.5) {
            return trim(n) + smallSuffixes[tier]
        }

        // Beyond T: use letter pairs aa, ab, ...
        // continue dividing
        if n >= 999.5 {
            n /= 1000
            tier += 1
        }
        while n >= 1000 {
            n /= 1000
            tier += 1
        }
        // One more normalization: floating-point near-1000 values (e.g. 999.9999…)
        // round to "1000" in trim(); advance tier to keep the display clean.
        if n >= 999.5 {
            n /= 1000
            tier += 1
        }
        let letterIndex = tier - smallSuffixes.count // tier 5 -> aa (index 0)
        return trim(n) + letterSuffix(letterIndex)
    }

    private static func trim(_ n: Double) -> String {
        if n >= 100 {
            return String(format: "%.0f", n)
        } else if n >= 10 {
            return String(format: "%.1f", n)
        } else {
            return String(format: "%.2f", n)
        }
    }

    private static func letterSuffix(_ index: Int) -> String {
        let i = max(0, index)
        let first = i / 26
        let second = i % 26
        let a = Character(UnicodeScalar(97 + first % 26)!)
        let b = Character(UnicodeScalar(97 + second)!)
        return String(a) + String(b)
    }

    // Depth shown in meters.
    static func depth(_ meters: Int) -> String {
        return number(Double(meters)) + " m"
    }

    // Time interval as compact "1h 23m" / "45s".
    static func duration(_ seconds: Double) -> String {
        let s = max(0, Int(seconds))
        if s < 60 { return "\(s)s" }
        let m = s / 60
        if m < 60 { return "\(m)m \(s % 60)s" }
        let h = m / 60
        if h < 24 { return "\(h)h \(m % 60)m" }
        let d = h / 24
        return "\(d)d \(h % 24)h"
    }
}
