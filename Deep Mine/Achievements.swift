import Foundation

struct DDMAchievement: Identifiable {
    let id: String
    let title: String
    let detail: String
    // returns progress 0...1 and whether unlocked, given the store snapshot.
    let evaluate: (DDMStore) -> (progress: Double, done: Bool)

    static func depthGoal(_ id: String, _ title: String, _ m: Int) -> DDMAchievement {
        DDMAchievement(id: id, title: title, detail: "Reach \(m) m deep.") { s in
            let p = min(1.0, Double(s.save.maxDepth) / Double(m))
            return (p, s.save.maxDepth >= m)
        }
    }

    static func goldGoal(_ id: String, _ title: String, _ g: Double) -> DDMAchievement {
        DDMAchievement(id: id, title: title, detail: "Earn \(DDMFormat.number(g)) gold in total.") { s in
            let p = min(1.0, s.save.lifetimeGoldEarned / g)
            return (p, s.save.lifetimeGoldEarned >= g)
        }
    }

    static func tapGoal(_ id: String, _ title: String, _ t: Int) -> DDMAchievement {
        DDMAchievement(id: id, title: title, detail: "Swing your pickaxe \(t) times.") { s in
            let p = min(1.0, Double(s.save.totalTaps) / Double(t))
            return (p, s.save.totalTaps >= t)
        }
    }

    static func collapseGoal(_ id: String, _ title: String, _ c: Int) -> DDMAchievement {
        DDMAchievement(id: id, title: title, detail: "Collapse the mine \(c) time\(c == 1 ? "" : "s").") { s in
            let p = min(1.0, Double(s.save.totalCollapses) / Double(c))
            return (p, s.save.totalCollapses >= c)
        }
    }

    static func gemGoal(_ id: String, _ title: String, _ g: Int) -> DDMAchievement {
        DDMAchievement(id: id, title: title, detail: "Hold \(g) gems.") { s in
            let p = min(1.0, Double(s.save.gems) / Double(g))
            return (p, s.save.gems >= g)
        }
    }

    static func oreGoal(_ id: String, _ title: String, _ ore: DDMOre, _ amt: Double) -> DDMAchievement {
        DDMAchievement(id: id, title: title, detail: "Mine \(DDMFormat.number(amt)) \(ore.name).") { s in
            let have = s.save.oreMinedTotals[ore.rawValue] ?? 0
            let p = min(1.0, have / amt)
            return (p, have >= amt)
        }
    }

    static let all: [DDMAchievement] = [
        depthGoal("d_25", "First Descent", 25),
        depthGoal("d_100", "Going Under", 100),
        depthGoal("d_250", "Deep Shaft", 250),
        depthGoal("d_500", "Half a Kilometer", 500),
        depthGoal("d_1000", "Kilometer Club", 1000),
        depthGoal("d_2000", "Abyss Walker", 2000),
        depthGoal("d_3500", "Mantle Bound", 3500),

        goldGoal("g_1k", "Pocket Change", 1_000),
        goldGoal("g_100k", "Vault Starter", 100_000),
        goldGoal("g_10m", "Gold Baron", 10_000_000),
        goldGoal("g_1b", "Billionaire Miner", 1_000_000_000),

        tapGoal("t_100", "Warm Up", 100),
        tapGoal("t_1000", "Steady Swing", 1_000),
        tapGoal("t_10000", "Iron Wrists", 10_000),

        collapseGoal("c_1", "First Collapse", 1),
        collapseGoal("c_5", "Reset Veteran", 5),
        collapseGoal("c_25", "Cycle Master", 25),

        gemGoal("gem_10", "Gem Cutter", 10),
        gemGoal("gem_100", "Gem Hoarder", 100),

        oreGoal("o_coal", "Coal Hauler", .coal, 500),
        oreGoal("o_iron", "Iron Veins", .iron, 300),
        oreGoal("o_gold", "Mother Lode", .gold, 200),
        oreGoal("o_diamond", "Diamond Hands", .diamond, 50)
    ]
}
