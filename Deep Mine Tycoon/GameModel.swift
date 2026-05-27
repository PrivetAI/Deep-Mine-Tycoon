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
    var baseValue: Double {
        switch self {
        case .coal: return 1
        case .copper: return 4
        case .tin: return 12
        case .iron: return 35
        case .silver: return 110
        case .gold: return 360
        case .ruby: return 1_200
        case .emerald: return 4_500
        case .sapphire: return 18_000
        case .diamond: return 75_000
        case .mithril: return 320_000
        case .obsidian: return 1_400_000
        }
    }

    // Depth (meters) at which this ore begins to appear.
    var unlockDepth: Int {
        switch self {
        case .coal: return 0
        case .copper: return 20
        case .tin: return 55
        case .iron: return 110
        case .silver: return 200
        case .gold: return 340
        case .ruby: return 560
        case .emerald: return 850
        case .sapphire: return 1_250
        case .diamond: return 1_800
        case .mithril: return 2_600
        case .obsidian: return 3_800
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

// MARK: - Upgrade definitions

enum DDMUpgradeKind: String, Codable, CaseIterable {
    case pickaxe        // tap damage
    case drillCount     // number of drills (auto dps base)
    case drillSpeed     // multiplier on auto dps
    case oreValue       // ore sell value multiplier
    case cart           // auto-collect / auto-sell rate
    case elevator       // depth skip per block clear bonus
    case refiner        // bonus gold per sale (refining)
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
                      blurb: "+ Tap damage to the dig face.",
                      baseCost: 15, costGrowth: 1.16, maxLevel: 999),
        DDMUpgradeDef(kind: .drillCount, title: "Drill Rig",
                      blurb: "Adds an auto-drill that chips rock for you.",
                      baseCost: 60, costGrowth: 1.21, maxLevel: 999),
        DDMUpgradeDef(kind: .drillSpeed, title: "Drill Tuning",
                      blurb: "Speeds up every drill's damage per second.",
                      baseCost: 250, costGrowth: 1.27, maxLevel: 999),
        DDMUpgradeDef(kind: .oreValue, title: "Ore Grader",
                      blurb: "Sorts ore better — raises sell value.",
                      baseCost: 400, costGrowth: 1.30, maxLevel: 999),
        DDMUpgradeDef(kind: .cart, title: "Mine Cart",
                      blurb: "Auto-collects and auto-sells mined ore.",
                      baseCost: 180, costGrowth: 1.24, maxLevel: 999),
        DDMUpgradeDef(kind: .elevator, title: "Elevator",
                      blurb: "Eases descent — small depth bonus per block.",
                      baseCost: 900, costGrowth: 1.33, maxLevel: 999),
        DDMUpgradeDef(kind: .refiner, title: "Refiner",
                      blurb: "Refines each sale for extra gold.",
                      baseCost: 600, costGrowth: 1.29, maxLevel: 999)
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
                     blurb: "+8% global gold & ore yield per level.",
                     baseCost: 2, costGrowth: 1.6, maxLevel: 200),
        DDMGlobalDef(kind: .startDepth, title: "Shaft Head Start",
                     blurb: "Begin each collapse 10 m deeper per level.",
                     baseCost: 4, costGrowth: 1.8, maxLevel: 100),
        DDMGlobalDef(kind: .offlineCap, title: "Night Shift",
                     blurb: "+2 h offline earnings cap per level.",
                     baseCost: 3, costGrowth: 1.7, maxLevel: 60),
        DDMGlobalDef(kind: .tapCrit, title: "Lucky Strikes",
                     blurb: "+3% chance a tap hits 5x (critical).",
                     baseCost: 5, costGrowth: 1.9, maxLevel: 25),
        DDMGlobalDef(kind: .autoStart, title: "Standing Rig",
                     blurb: "Keep 1 extra drill after collapse per level.",
                     baseCost: 6, costGrowth: 2.0, maxLevel: 30)
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
    }
}

// MARK: - Block model (current dig face)

struct DDMBlock {
    let depth: Int
    let maxHP: Double
    var hp: Double
    let oreType: DDMOre?     // ore vein in this block (nil = plain rubble)
    let oreAmount: Double    // ore units dropped when cleared
    let rubbleGold: Double   // small base gold from rubble
}

// MARK: - Block / depth math (deterministic)

enum DDMWorld {
    // HP of a block at a given depth.
    static func blockHP(depth: Int) -> Double {
        let d = Double(max(0, depth))
        // smooth exponential-ish scaling
        let hp = 10.0 * pow(1.045, d) + d * 6.0 + 10.0
        return hp.isFinite ? max(10.0, hp) : 10.0
    }

    // Generate a block deterministically from depth.
    static func block(at depth: Int) -> DDMBlock {
        var rng = DDMRandom(seed: ddmSeed(depth, 0xDEEB))
        let hp = blockHP(depth: depth)

        // determine the richest ore unlocked by this depth, then pick from a band.
        let unlocked = DDMOre.allCases.filter { $0.unlockDepth <= depth }
        let topIndex = (unlocked.last?.rawValue ?? 0)

        // ore chance rises slightly with depth band
        let oreChance = 0.34 + min(0.22, Double(depth) * 0.00004)
        var oreType: DDMOre? = nil
        var oreAmount: Double = 0

        if rng.chance(oreChance) && !unlocked.isEmpty {
            // bias toward the top few unlocked tiers
            let lowest = max(0, topIndex - 3)
            let pick = rng.nextInt(lowest, topIndex)
            oreType = DDMOre(rawValue: pick)
            // amount scales gently with depth
            let baseAmt = Double(rng.nextInt(2, 6))
            oreAmount = (baseAmt + Double(depth) * 0.01).rounded()
            if oreAmount < 1 { oreAmount = 1 }
        }

        let rubble = (1.0 + Double(depth) * 0.05).rounded()
        return DDMBlock(depth: depth, maxHP: hp, hp: hp,
                        oreType: oreType, oreAmount: oreAmount,
                        rubbleGold: max(1, rubble))
    }
}
