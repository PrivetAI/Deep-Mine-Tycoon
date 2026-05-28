import SwiftUI

// MARK: - Ore types

enum DDMOre: Int, CaseIterable, Codable {
    case coal = 0
    case copper
    case tin
    case iron
    case silver
    case gold
    case ruby
    case emerald
    case sapphire
    case diamond
    case mithril   // exotic
    case obsidian  // exotic

    var name: String {
        switch self {
        case .coal: return "Coal"
        case .copper: return "Copper"
        case .tin: return "Tin"
        case .iron: return "Iron"
        case .silver: return "Silver"
        case .gold: return "Gold Ore"
        case .ruby: return "Ruby"
        case .emerald: return "Emerald"
        case .sapphire: return "Sapphire"
        case .diamond: return "Diamond"
        case .mithril: return "Mithril"
        case .obsidian: return "Obsidian"
        }
    }

    // Base sell value per unit of ore.
    // Tuned so each tier is ~5x the previous and tiers unlock fast enough that
    // gold income keeps geometric pace with exponential upgrade costs.
    var baseValue: Double {
        switch self {
        case .coal: return 2
        case .copper: return 10
        case .tin: return 50
        case .iron: return 260
        case .silver: return 1_300
        case .gold: return 6_500
        case .ruby: return 32_000
        case .emerald: return 160_000
        case .sapphire: return 820_000
        case .diamond: return 4_200_000
        case .mithril: return 22_000_000
        case .obsidian: return 120_000_000
        }
    }

    // Depth (meters) at which this ore begins to appear.
    // Tightened so deep tiers are reachable in a normal session + prestige cycles.
    var unlockDepth: Int {
        switch self {
        case .coal: return 0
        case .copper: return 15
        case .tin: return 40
        case .iron: return 80
        case .silver: return 140
        case .gold: return 230
        case .ruby: return 360
        case .emerald: return 540
        case .sapphire: return 780
        case .diamond: return 1_100
        case .mithril: return 1_500
        case .obsidian: return 2_000
        }
    }

    var color: Color {
        switch self {
        case .coal: return Color(red: 0.20, green: 0.20, blue: 0.22)
        case .copper: return Color(red: 0.78, green: 0.45, blue: 0.27)
        case .tin: return Color(red: 0.66, green: 0.68, blue: 0.72)
        case .iron: return Color(red: 0.52, green: 0.54, blue: 0.58)
        case .silver: return Color(red: 0.84, green: 0.86, blue: 0.90)
        case .gold: return DDMPalette.gold
        case .ruby: return Color(red: 0.84, green: 0.18, blue: 0.30)
        case .emerald: return Color(red: 0.20, green: 0.72, blue: 0.46)
        case .sapphire: return Color(red: 0.24, green: 0.42, blue: 0.86)
        case .diamond: return Color(red: 0.70, green: 0.90, blue: 0.96)
        case .mithril: return Color(red: 0.60, green: 0.80, blue: 0.78)
        case .obsidian: return Color(red: 0.32, green: 0.18, blue: 0.40)
        }
    }
}

// MARK: - Zones / strata

// A depth band with its own name, palette and economy modifiers.
// Zone is derived purely from depth — no save migration needed.
struct DDMZone: Identifiable {
    let index: Int
    let name: String
    let startDepth: Int       // inclusive
    let endDepth: Int         // exclusive (Int.max for the last zone)
    let hpMult: Double        // multiplies block HP within this zone
    let goldMult: Double      // multiplies rubble / sale gold within this zone
    let oreMult: Double       // multiplies ore drop amount within this zone
    // Palette for the strata background.
    let bandA: Color
    let bandB: Color
    let baseFill: Color
    let accent: Color

    var id: Int { index }

    var spanText: String {
        if endDepth == Int.max { return "\(startDepth) m +" }
        return "\(startDepth)–\(endDepth) m"
    }

    static let all: [DDMZone] = [
        DDMZone(index: 0, name: "Topsoil", startDepth: 0, endDepth: 80,
                hpMult: 1.0, goldMult: 1.0, oreMult: 1.0,
                bandA: Color(red: 0.45, green: 0.32, blue: 0.21),
                bandB: Color(red: 0.33, green: 0.23, blue: 0.15),
                baseFill: Color(red: 0.30, green: 0.21, blue: 0.13),
                accent: Color(red: 0.57, green: 0.42, blue: 0.28)),
        DDMZone(index: 1, name: "Stone Shelf", startDepth: 80, endDepth: 230,
                hpMult: 1.6, goldMult: 1.6, oreMult: 1.3,
                bandA: Color(red: 0.40, green: 0.36, blue: 0.33),
                bandB: Color(red: 0.30, green: 0.27, blue: 0.24),
                baseFill: Color(red: 0.26, green: 0.24, blue: 0.22),
                accent: Color(red: 0.52, green: 0.47, blue: 0.43)),
        DDMZone(index: 2, name: "Crystal Caverns", startDepth: 230, endDepth: 540,
                hpMult: 2.6, goldMult: 2.6, oreMult: 1.7,
                bandA: Color(red: 0.26, green: 0.34, blue: 0.46),
                bandB: Color(red: 0.18, green: 0.25, blue: 0.36),
                baseFill: Color(red: 0.14, green: 0.20, blue: 0.30),
                accent: Color(red: 0.46, green: 0.74, blue: 0.86)),
        DDMZone(index: 3, name: "Magma Veins", startDepth: 540, endDepth: 1_100,
                hpMult: 4.2, goldMult: 4.2, oreMult: 2.2,
                bandA: Color(red: 0.46, green: 0.20, blue: 0.14),
                bandB: Color(red: 0.34, green: 0.13, blue: 0.09),
                baseFill: Color(red: 0.28, green: 0.10, blue: 0.07),
                accent: Color(red: 0.96, green: 0.52, blue: 0.20)),
        DDMZone(index: 4, name: "The Abyss", startDepth: 1_100, endDepth: 2_000,
                hpMult: 7.0, goldMult: 7.0, oreMult: 3.0,
                bandA: Color(red: 0.22, green: 0.18, blue: 0.34),
                bandB: Color(red: 0.15, green: 0.12, blue: 0.26),
                baseFill: Color(red: 0.11, green: 0.09, blue: 0.20),
                accent: Color(red: 0.62, green: 0.52, blue: 0.92)),
        DDMZone(index: 5, name: "World's Core", startDepth: 2_000, endDepth: Int.max,
                hpMult: 12.0, goldMult: 12.0, oreMult: 4.0,
                bandA: Color(red: 0.40, green: 0.30, blue: 0.10),
                bandB: Color(red: 0.28, green: 0.20, blue: 0.06),
                baseFill: Color(red: 0.20, green: 0.14, blue: 0.04),
                accent: Color(red: 0.98, green: 0.78, blue: 0.30))
    ]

    static func zone(at depth: Int) -> DDMZone {
        let d = max(0, depth)
        for z in all where d >= z.startDepth && d < z.endDepth {
            return z
        }
        return all.last!
    }

    // The boss-gate depth at the END of this zone (the block that gates the next).
    var bossDepth: Int? {
        endDepth == Int.max ? nil : endDepth - 1
    }

    // Is this exact depth a boss/bedrock gate?
    static func isBossDepth(_ depth: Int) -> Bool {
        for z in all where z.endDepth != Int.max {
            if z.endDepth - 1 == depth { return true }
        }
        return false
    }

    var next: DDMZone? {
        DDMZone.all.first(where: { $0.index == index + 1 })
    }
}

// MARK: - Upgrade definitions

enum DDMUpgradeKind: String, Codable, CaseIterable {
    case pickaxe        // tap damage
    case drillCount     // number of drills (auto dps base)
    case drillSpeed     // multiplier on auto dps
    case oreValue       // ore sell value multiplier
    case cart           // auto-collect / auto-sell rate
    case elevator       // depth skip per block clear bonus
    case refiner        // bonus gold per sale (refining)
    case dynamite       // burst / boss tap damage
}

struct DDMUpgradeDef: Identifiable {
    let kind: DDMUpgradeKind
    let title: String
    let blurb: String
    let baseCost: Double
    let costGrowth: Double
    let maxLevel: Int

    var id: String { kind.rawValue }

    func cost(at level: Int) -> Double {
        let c = baseCost * pow(costGrowth, Double(level))
        return c.isFinite ? c.rounded() : Double.greatestFiniteMagnitude
    }

    static let all: [DDMUpgradeDef] = [
        DDMUpgradeDef(kind: .pickaxe, title: "Pickaxe Power",
                      blurb: "+ Tap damage. Doubles every 25 levels.",
                      baseCost: 15, costGrowth: 1.15, maxLevel: 9999),
        DDMUpgradeDef(kind: .drillCount, title: "Drill Rig",
                      blurb: "Adds an auto-drill. Doubles output every 25.",
                      baseCost: 60, costGrowth: 1.17, maxLevel: 9999),
        DDMUpgradeDef(kind: .drillSpeed, title: "Drill Tuning",
                      blurb: "Speeds up drills. Doubles every 25 levels.",
                      baseCost: 250, costGrowth: 1.19, maxLevel: 9999),
        DDMUpgradeDef(kind: .oreValue, title: "Ore Grader",
                      blurb: "Sorts ore better — raises sell value.",
                      baseCost: 400, costGrowth: 1.22, maxLevel: 9999),
        DDMUpgradeDef(kind: .cart, title: "Mine Cart",
                      blurb: "Auto-collects and auto-sells mined ore.",
                      baseCost: 180, costGrowth: 1.20, maxLevel: 9999),
        DDMUpgradeDef(kind: .elevator, title: "Elevator",
                      blurb: "Eases descent — small depth bonus per block.",
                      baseCost: 900, costGrowth: 1.28, maxLevel: 200),
        DDMUpgradeDef(kind: .refiner, title: "Refiner",
                      blurb: "Refines each sale for extra gold.",
                      baseCost: 600, costGrowth: 1.21, maxLevel: 9999),
        DDMUpgradeDef(kind: .dynamite, title: "Dynamite Charge",
                      blurb: "Big bonus tap damage vs bedrock & bosses.",
                      baseCost: 1_200, costGrowth: 1.24, maxLevel: 9999)
    ]

    static func def(_ kind: DDMUpgradeKind) -> DDMUpgradeDef {
        all.first(where: { $0.kind == kind })!
    }
}

// MARK: - Global (prestige) upgrades — bought with Gems

enum DDMGlobalKind: String, Codable, CaseIterable {
    case yieldBoost      // % global yield per level
    case startDepth      // start depth after collapse
    case offlineCap      // raise offline earnings cap (hours)
    case tapCrit         // chance for critical taps
    case autoStart       // free starting drills after collapse
    case critPower       // critical hit multiplier
    case treasureLuck    // treasure / geode chance
    case oreMagnet       // ore drop amount multiplier
}

struct DDMGlobalDef: Identifiable {
    let kind: DDMGlobalKind
    let title: String
    let blurb: String
    let baseCost: Int
    let costGrowth: Double
    let maxLevel: Int

    var id: String { kind.rawValue }

    func cost(at level: Int) -> Int {
        let c = Double(baseCost) * pow(costGrowth, Double(level))
        if !c.isFinite { return Int.max }
        return Int(c.rounded())
    }

    static let all: [DDMGlobalDef] = [
        DDMGlobalDef(kind: .yieldBoost, title: "Deep Veins",
                     blurb: "+15% global gold & ore yield per level.",
                     baseCost: 2, costGrowth: 1.45, maxLevel: 300),
        DDMGlobalDef(kind: .startDepth, title: "Shaft Head Start",
                     blurb: "Begin each collapse 15 m deeper per level.",
                     baseCost: 3, costGrowth: 1.5, maxLevel: 200),
        DDMGlobalDef(kind: .offlineCap, title: "Night Shift",
                     blurb: "+2 h offline earnings cap per level.",
                     baseCost: 3, costGrowth: 1.55, maxLevel: 60),
        DDMGlobalDef(kind: .tapCrit, title: "Lucky Strikes",
                     blurb: "+3% chance a tap lands a critical.",
                     baseCost: 5, costGrowth: 1.6, maxLevel: 25),
        DDMGlobalDef(kind: .autoStart, title: "Standing Rig",
                     blurb: "Keep 2 extra drills after collapse per level.",
                     baseCost: 4, costGrowth: 1.55, maxLevel: 60),
        DDMGlobalDef(kind: .critPower, title: "Detonator",
                     blurb: "+1.0x critical-hit damage per level.",
                     baseCost: 6, costGrowth: 1.6, maxLevel: 40),
        DDMGlobalDef(kind: .treasureLuck, title: "Prospector's Eye",
                     blurb: "+25% treasure & geode find chance per level.",
                     baseCost: 5, costGrowth: 1.55, maxLevel: 40),
        DDMGlobalDef(kind: .oreMagnet, title: "Ore Magnet",
                     blurb: "+20% ore mined per block per level.",
                     baseCost: 4, costGrowth: 1.5, maxLevel: 60)
    ]

    static func def(_ kind: DDMGlobalKind) -> DDMGlobalDef {
        all.first(where: { $0.kind == kind })!
    }
}

// MARK: - Settings

struct DDMSettings: Codable {
    var soundOn: Bool = true
    var hapticsOn: Bool = true

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        soundOn = try c.decodeIfPresent(Bool.self, forKey: .soundOn) ?? true
        hapticsOn = try c.decodeIfPresent(Bool.self, forKey: .hapticsOn) ?? true
    }
}

// MARK: - Save data

struct DDMSave: Codable {
    var gold: Double = 0
    var depth: Int = 0                 // current depth (meters)
    var maxDepth: Int = 0              // max reached this run-history (lifetime)
    var runMaxDepth: Int = 0           // max reached this collapse run
    var currentBlockHP: Double = -1    // -1 means "regenerate from depth"
    var oreCounts: [Int: Double] = [:] // ore raw -> count held (not yet sold)
    var upgrades: [String: Int] = [:]  // upgrade kind raw -> level
    var globals: [String: Int] = [:]   // global kind raw -> level
    var gems: Int = 0
    var lifetimeOreSold: Double = 0
    var lifetimeGoldEarned: Double = 0
    var oreMinedTotals: [Int: Double] = [:] // lifetime mined per ore
    var lastActive: Double = 0          // timeIntervalSince1970
    var totalTaps: Int = 0
    var totalCollapses: Int = 0

    // --- additive fields (decoded with decodeIfPresent ?? default) ---
    var oreSoldClaimed: Double = 0      // lifetimeOreSold accounted for at last collapse
    var claimedMilestones: [Int] = []   // depth-milestone thresholds already rewarded
    var bossesDefeated: Int = 0         // lifetime bedrock bosses cleared
    var treasuresFound: Int = 0         // lifetime treasure/geode blocks cleared

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gold = try c.decodeIfPresent(Double.self, forKey: .gold) ?? 0
        depth = try c.decodeIfPresent(Int.self, forKey: .depth) ?? 0
        maxDepth = try c.decodeIfPresent(Int.self, forKey: .maxDepth) ?? 0
        runMaxDepth = try c.decodeIfPresent(Int.self, forKey: .runMaxDepth) ?? 0
        currentBlockHP = try c.decodeIfPresent(Double.self, forKey: .currentBlockHP) ?? -1
        oreCounts = try c.decodeIfPresent([Int: Double].self, forKey: .oreCounts) ?? [:]
        upgrades = try c.decodeIfPresent([String: Int].self, forKey: .upgrades) ?? [:]
        globals = try c.decodeIfPresent([String: Int].self, forKey: .globals) ?? [:]
        gems = try c.decodeIfPresent(Int.self, forKey: .gems) ?? 0
        lifetimeOreSold = try c.decodeIfPresent(Double.self, forKey: .lifetimeOreSold) ?? 0
        lifetimeGoldEarned = try c.decodeIfPresent(Double.self, forKey: .lifetimeGoldEarned) ?? 0
        oreMinedTotals = try c.decodeIfPresent([Int: Double].self, forKey: .oreMinedTotals) ?? [:]
        lastActive = try c.decodeIfPresent(Double.self, forKey: .lastActive) ?? 0
        totalTaps = try c.decodeIfPresent(Int.self, forKey: .totalTaps) ?? 0
        totalCollapses = try c.decodeIfPresent(Int.self, forKey: .totalCollapses) ?? 0
        oreSoldClaimed = try c.decodeIfPresent(Double.self, forKey: .oreSoldClaimed) ?? 0
        claimedMilestones = try c.decodeIfPresent([Int].self, forKey: .claimedMilestones) ?? []
        bossesDefeated = try c.decodeIfPresent(Int.self, forKey: .bossesDefeated) ?? 0
        treasuresFound = try c.decodeIfPresent(Int.self, forKey: .treasuresFound) ?? 0
    }
}

// MARK: - Block model (current dig face)

enum DDMBlockKind: Equatable {
    case normal
    case treasure   // geode — bonus gold / gem find / rare ore burst
    case boss       // bedrock gate at a zone boundary
}

struct DDMBlock {
    let depth: Int
    let maxHP: Double
    var hp: Double
    let oreType: DDMOre?     // ore vein in this block (nil = plain rubble)
    let oreAmount: Double    // ore units dropped when cleared
    let rubbleGold: Double   // small base gold from rubble
    let kind: DDMBlockKind   // normal / treasure / boss
    // Treasure / boss reward seeds (resolved at clear time via store stats).
    let bonusGold: Double    // extra gold awarded on clear (treasure/boss)
    let gemReward: Int       // gems awarded on clear (treasure/boss)
    let bonusOre: DDMOre?    // burst of rare ore on clear
    let bonusOreAmount: Double

    var isBoss: Bool { kind == .boss }
    var isTreasure: Bool { kind == .treasure }
}

// MARK: - Block / depth math (deterministic)

enum DDMWorld {
    // Depth milestone thresholds that grant a one-time gold+gem reward.
    static let milestones: [Int] = [50, 120, 250, 450, 700, 1_000, 1_400, 2_000, 2_800, 4_000, 6_000]

    static func milestoneReward(_ m: Int) -> (gold: Double, gems: Int) {
        // gold scales with the difficulty of reaching the depth; gems are a small bump.
        let gold = 50.0 * pow(Double(m), 1.9)
        let gems = max(1, m / 200)
        return (gold.rounded(), gems)
    }

    // HP of a block at a given depth.
    // Very gentle exponential (+0.35%/m, HP doubles ~every 198 m) plus a per-zone step
    // multiplier so depth advances at a STEADY pace relative to achievable DPS.
    // This is the key fix for the old +4.5%/m wall that outran damage by ~50-100 m.
    static func blockHP(depth: Int) -> Double {
        let d = Double(max(0, depth))
        let zone = DDMZone.zone(at: depth)
        let base = 10.0 * pow(1.0035, d) + d * 1.0 + 10.0
        var hp = base * zone.hpMult
        if DDMZone.isBossDepth(depth) {
            hp *= 8.0 // bedrock gate — a real speed bump, beatable with burst taps/auto
        }
        return hp.isFinite ? max(10.0, hp) : 10.0
    }

    // Generate a block deterministically from depth.
    static func block(at depth: Int) -> DDMBlock {
        var rng = DDMRandom(seed: ddmSeed(depth, 0xDEEB))
        let hp = blockHP(depth: depth)
        let zone = DDMZone.zone(at: depth)

        // determine the richest ore unlocked by this depth, then pick from a band.
        let unlocked = DDMOre.allCases.filter { $0.unlockDepth <= depth }
        let topIndex = (unlocked.last?.rawValue ?? 0)

        // ore chance rises slightly with depth band
        let oreChance = 0.40 + min(0.25, Double(depth) * 0.00005)
        var oreType: DDMOre? = nil
        var oreAmount: Double = 0

        if rng.chance(oreChance) && !unlocked.isEmpty {
            // bias toward the top few unlocked tiers
            let lowest = max(0, topIndex - 3)
            let pick = rng.nextInt(lowest, topIndex)
            oreType = DDMOre(rawValue: pick)
            let baseAmt = Double(rng.nextInt(3, 8))
            oreAmount = ((baseAmt + Double(depth) * 0.02) * zone.oreMult).rounded()
            if oreAmount < 1 { oreAmount = 1 }
        }

        let rubble = ((2.0 + Double(depth) * 0.12) * zone.goldMult).rounded()

        // Boss gate?
        if DDMZone.isBossDepth(depth) {
            // Boss reward scales with depth; gems give prestige a steady drip.
            let bossGold = (rubble * 30.0 + 200.0 * pow(Double(max(1, depth)), 1.4)).rounded()
            let bossGems = max(2, depth / 250 + 2)
            // a guaranteed burst of the richest unlocked ore
            let richOre = unlocked.last ?? .coal
            let bossOreAmt = (Double(rng.nextInt(20, 40)) * zone.oreMult).rounded()
            return DDMBlock(depth: depth, maxHP: hp, hp: hp,
                            oreType: oreType, oreAmount: oreAmount,
                            rubbleGold: max(1, rubble), kind: .boss,
                            bonusGold: bossGold, gemReward: bossGems,
                            bonusOre: richOre, bonusOreAmount: bossOreAmt)
        }

        // Treasure / geode? deterministic, seeded from depth.
        // Base ~3.5%; treasureLuck global raises it (applied in store via reroll, but
        // base chance baked here for determinism). We keep base chance here and let the
        // store decide extra finds; this flag marks the *guaranteed* base geodes.
        let treasureRoll = rng.nextDouble()
        if depth > 5 && treasureRoll < 0.035 {
            let tGold = (rubble * 12.0 + 60.0 * pow(Double(max(1, depth)), 1.2)).rounded()
            let tGem = rng.chance(0.18) ? 1 : 0
            let richOre = unlocked.last ?? .coal
            let tOreAmt = (Double(rng.nextInt(8, 18)) * zone.oreMult).rounded()
            return DDMBlock(depth: depth, maxHP: hp, hp: hp,
                            oreType: oreType, oreAmount: oreAmount,
                            rubbleGold: max(1, rubble), kind: .treasure,
                            bonusGold: tGold, gemReward: tGem,
                            bonusOre: richOre, bonusOreAmount: tOreAmt)
        }

        return DDMBlock(depth: depth, maxHP: hp, hp: hp,
                        oreType: oreType, oreAmount: oreAmount,
                        rubbleGold: max(1, rubble), kind: .normal,
                        bonusGold: 0, gemReward: 0,
                        bonusOre: nil, bonusOreAmount: 0)
    }
}
