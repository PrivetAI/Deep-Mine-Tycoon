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
    case mithril    // exotic
    case obsidian   // exotic
    case adamantite // deep exotic
    case voidstone  // deep exotic
    case starmetal  // deep exotic
    case aetherium  // deepest exotic

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
        case .adamantite: return "Adamantite"
        case .voidstone: return "Voidstone"
        case .starmetal: return "Starmetal"
        case .aetherium: return "Aetherium"
        }
    }

    // Base sell value per unit of ore.
    // Each tier is ~4.5x the previous. Income from richer ore still climbs geometrically
    // with depth, but the upgrade cost curves now climb FASTER (see DDMUpgradeDef), so a
    // single new ore tier no longer trivially funds every upgrade.
    var baseValue: Double {
        switch self {
        case .coal: return 1
        case .copper: return 4
        case .tin: return 11
        case .iron: return 28
        case .silver: return 72
        case .gold: return 180
        case .ruby: return 460
        case .emerald: return 1_200
        case .sapphire: return 3_100
        case .diamond: return 8_000
        case .mithril: return 21_000
        case .obsidian: return 55_000
        case .adamantite: return 143_000
        case .voidstone: return 372_000
        case .starmetal: return 970_000
        case .aetherium: return 2_500_000
        }
    }

    // Depth (meters) at which this ore begins to appear.
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
        case .adamantite: return 2_700
        case .voidstone: return 3_600
        case .starmetal: return 4_800
        case .aetherium: return 6_400
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
        case .adamantite: return Color(red: 0.48, green: 0.84, blue: 0.62)
        case .voidstone: return Color(red: 0.30, green: 0.16, blue: 0.46)
        case .starmetal: return Color(red: 0.62, green: 0.70, blue: 0.96)
        case .aetherium: return Color(red: 0.96, green: 0.86, blue: 0.56)
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
        DDMZone(index: 5, name: "World's Core", startDepth: 2_000, endDepth: 2_700,
                hpMult: 12.0, goldMult: 12.0, oreMult: 4.0,
                bandA: Color(red: 0.40, green: 0.30, blue: 0.10),
                bandB: Color(red: 0.28, green: 0.20, blue: 0.06),
                baseFill: Color(red: 0.20, green: 0.14, blue: 0.04),
                accent: Color(red: 0.98, green: 0.78, blue: 0.30)),
        DDMZone(index: 6, name: "Mantle Forge", startDepth: 2_700, endDepth: 3_600,
                hpMult: 19.0, goldMult: 18.0, oreMult: 5.0,
                bandA: Color(red: 0.20, green: 0.46, blue: 0.34),
                bandB: Color(red: 0.13, green: 0.34, blue: 0.25),
                baseFill: Color(red: 0.08, green: 0.24, blue: 0.18),
                accent: Color(red: 0.42, green: 0.92, blue: 0.66)),
        DDMZone(index: 7, name: "The Void Rift", startDepth: 3_600, endDepth: 4_800,
                hpMult: 30.0, goldMult: 28.0, oreMult: 6.5,
                bandA: Color(red: 0.20, green: 0.12, blue: 0.34),
                bandB: Color(red: 0.13, green: 0.07, blue: 0.24),
                baseFill: Color(red: 0.09, green: 0.05, blue: 0.18),
                accent: Color(red: 0.66, green: 0.40, blue: 0.96)),
        DDMZone(index: 8, name: "Stellar Vault", startDepth: 4_800, endDepth: 6_400,
                hpMult: 48.0, goldMult: 44.0, oreMult: 8.0,
                bandA: Color(red: 0.20, green: 0.26, blue: 0.46),
                bandB: Color(red: 0.13, green: 0.18, blue: 0.36),
                baseFill: Color(red: 0.08, green: 0.12, blue: 0.28),
                accent: Color(red: 0.62, green: 0.74, blue: 0.98)),
        DDMZone(index: 9, name: "Aether Wellspring", startDepth: 6_400, endDepth: Int.max,
                hpMult: 76.0, goldMult: 70.0, oreMult: 10.0,
                bandA: Color(red: 0.44, green: 0.38, blue: 0.18),
                bandB: Color(red: 0.32, green: 0.27, blue: 0.10),
                baseFill: Color(red: 0.22, green: 0.18, blue: 0.06),
                accent: Color(red: 0.98, green: 0.90, blue: 0.56))
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
    // --- new lines ---
    case multiTap       // each tap counts as N strikes
    case autoTapper     // automatic taps per second (uses tap damage)
    case depthScaling   // tap & auto damage scale with current depth
    case goldFind       // % bonus gold from rubble & sales
    case drillEfficiency// multiplier on auto dps
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

    // Cost curves are deliberately STEEP (growth 1.33–1.55) on top of higher base costs.
    // With the tempered income (softer gem mult + ×2-every-35 milestones, see Store), the
    // cost of the next level is always a meaningful multiple of current income, so a fresh
    // player buys a handful of early levels quickly, then each line stretches from seconds
    // to minutes — and deep lines require descending / prestiging to afford at all.
    // Cost ladder: base cost ascends with the upgrade's power (cheap basics ->
    // pricier multipliers), uniform ~1.5 growth so curves stay proportional.
    static let all: [DDMUpgradeDef] = [
        DDMUpgradeDef(kind: .pickaxe, title: "Pickaxe Power",
                      blurb: "+ Tap damage.",
                      baseCost: 25, costGrowth: 1.45, maxLevel: 9999),
        DDMUpgradeDef(kind: .cart, title: "Mine Cart",
                      blurb: "Auto-collects and auto-sells mined ore.",
                      baseCost: 150, costGrowth: 1.50, maxLevel: 9999),
        DDMUpgradeDef(kind: .drillCount, title: "Drill Rig",
                      blurb: "Adds an auto-drill that mines for you.",
                      baseCost: 400, costGrowth: 1.50, maxLevel: 9999),
        DDMUpgradeDef(kind: .drillSpeed, title: "Drill Tuning",
                      blurb: "Speeds up every drill.",
                      baseCost: 1_500, costGrowth: 1.50, maxLevel: 9999),
        DDMUpgradeDef(kind: .dynamite, title: "Dynamite Charge",
                      blurb: "Bonus tap damage vs bedrock & bosses.",
                      baseCost: 2_500, costGrowth: 1.50, maxLevel: 9999),
        DDMUpgradeDef(kind: .oreValue, title: "Ore Grader",
                      blurb: "Sorts ore better — raises sell value.",
                      baseCost: 3_000, costGrowth: 1.50, maxLevel: 9999),
        DDMUpgradeDef(kind: .refiner, title: "Refiner",
                      blurb: "Refines each sale for extra gold.",
                      baseCost: 5_000, costGrowth: 1.50, maxLevel: 9999),
        DDMUpgradeDef(kind: .elevator, title: "Elevator",
                      blurb: "Eases descent — small depth bonus per block.",
                      baseCost: 6_000, costGrowth: 1.50, maxLevel: 200),
        DDMUpgradeDef(kind: .drillEfficiency, title: "Drill Gearing",
                      blurb: "Raises auto mining output.",
                      baseCost: 8_000, costGrowth: 1.50, maxLevel: 9999),
        DDMUpgradeDef(kind: .goldFind, title: "Prospect Sense",
                      blurb: "More gold from rubble & sales.",
                      baseCost: 10_000, costGrowth: 1.50, maxLevel: 9999),
        DDMUpgradeDef(kind: .multiTap, title: "Multi-Strike",
                      blurb: "Each tap lands +1 extra strike per level.",
                      baseCost: 15_000, costGrowth: 1.55, maxLevel: 60),
        DDMUpgradeDef(kind: .autoTapper, title: "Auto Pick",
                      blurb: "A mechanical arm auto-taps for you.",
                      baseCost: 20_000, costGrowth: 1.50, maxLevel: 200),
        DDMUpgradeDef(kind: .depthScaling, title: "Pressure Drill",
                      blurb: "All damage rises with current depth.",
                      baseCost: 30_000, costGrowth: 1.50, maxLevel: 300)
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
    // --- new globals ---
    case startGold       // start each collapse with a gold stake
    case researchRate    // % more research points
    case smeltSpeed      // % faster smelting
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
                     blurb: "+12% global gold & ore yield per level.",
                     baseCost: 3, costGrowth: 1.55, maxLevel: 300),
        DDMGlobalDef(kind: .startDepth, title: "Shaft Head Start",
                     blurb: "Begin each collapse 15 m deeper per level.",
                     baseCost: 4, costGrowth: 1.6, maxLevel: 200),
        DDMGlobalDef(kind: .offlineCap, title: "Night Shift",
                     blurb: "+2 h offline earnings cap per level.",
                     baseCost: 4, costGrowth: 1.6, maxLevel: 60),
        DDMGlobalDef(kind: .tapCrit, title: "Lucky Strikes",
                     blurb: "+3% chance a tap lands a critical.",
                     baseCost: 6, costGrowth: 1.65, maxLevel: 25),
        DDMGlobalDef(kind: .autoStart, title: "Standing Rig",
                     blurb: "Keep 2 extra drills after collapse per level.",
                     baseCost: 5, costGrowth: 1.6, maxLevel: 60),
        DDMGlobalDef(kind: .critPower, title: "Detonator",
                     blurb: "+1.0x critical-hit damage per level.",
                     baseCost: 7, costGrowth: 1.65, maxLevel: 40),
        DDMGlobalDef(kind: .treasureLuck, title: "Prospector's Eye",
                     blurb: "+25% treasure & geode find chance per level.",
                     baseCost: 6, costGrowth: 1.6, maxLevel: 40),
        DDMGlobalDef(kind: .oreMagnet, title: "Ore Magnet",
                     blurb: "+20% ore mined per block per level.",
                     baseCost: 5, costGrowth: 1.55, maxLevel: 60),
        // --- new globals ---
        DDMGlobalDef(kind: .startGold, title: "Seed Vault",
                     blurb: "Begin each collapse with a larger gold stake.",
                     baseCost: 6, costGrowth: 1.6, maxLevel: 50),
        DDMGlobalDef(kind: .researchRate, title: "Field Lab",
                     blurb: "+20% Research Points earned per level.",
                     baseCost: 8, costGrowth: 1.62, maxLevel: 40),
        DDMGlobalDef(kind: .smeltSpeed, title: "Forge Draft",
                     blurb: "+15% smelting speed per level.",
                     baseCost: 8, costGrowth: 1.6, maxLevel: 40)
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

    // --- Cores (second prestige layer "Tectonic Shift") ---
    var cores: Int = 0                  // spendable meta currency
    var lifetimeCores: Int = 0          // total cores ever gained
    var gemsClaimedForCores: Int = 0    // gems-basis already converted to cores
    var collapsesClaimedForCores: Int = 0
    var totalShifts: Int = 0            // number of Tectonic Shifts performed
    var metaTree: [String: Int] = [:]   // meta-perk kind raw -> level (persists through collapse)

    // --- Research ---
    var research: Double = 0            // spendable research points
    var lifetimeResearch: Double = 0
    var researchClaimedDepth: Int = 0   // maxDepth basis already paid out as research
    var techs: [String: Int] = [:]      // tech kind raw -> level

    // --- Smelter ---
    var bars: [Int: Double] = [:]       // ore raw -> refined bar count held
    var smelterUpgrades: [String: Int] = [:] // smelter upgrade kind raw -> level
    var lifetimeBarsValue: Double = 0

    // --- Per-ore mastery ---
    var oreMastery: [Int: Int] = [:]    // ore raw -> mastery level

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
        // additive — Cores
        cores = try c.decodeIfPresent(Int.self, forKey: .cores) ?? 0
        lifetimeCores = try c.decodeIfPresent(Int.self, forKey: .lifetimeCores) ?? 0
        gemsClaimedForCores = try c.decodeIfPresent(Int.self, forKey: .gemsClaimedForCores) ?? 0
        collapsesClaimedForCores = try c.decodeIfPresent(Int.self, forKey: .collapsesClaimedForCores) ?? 0
        totalShifts = try c.decodeIfPresent(Int.self, forKey: .totalShifts) ?? 0
        metaTree = try c.decodeIfPresent([String: Int].self, forKey: .metaTree) ?? [:]
        // additive — Research
        research = try c.decodeIfPresent(Double.self, forKey: .research) ?? 0
        lifetimeResearch = try c.decodeIfPresent(Double.self, forKey: .lifetimeResearch) ?? 0
        researchClaimedDepth = try c.decodeIfPresent(Int.self, forKey: .researchClaimedDepth) ?? 0
        techs = try c.decodeIfPresent([String: Int].self, forKey: .techs) ?? [:]
        // additive — Smelter
        bars = try c.decodeIfPresent([Int: Double].self, forKey: .bars) ?? [:]
        smelterUpgrades = try c.decodeIfPresent([String: Int].self, forKey: .smelterUpgrades) ?? [:]
        lifetimeBarsValue = try c.decodeIfPresent(Double.self, forKey: .lifetimeBarsValue) ?? 0
        // additive — Per-ore mastery
        oreMastery = try c.decodeIfPresent([Int: Int].self, forKey: .oreMastery) ?? [:]
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
    static let milestones: [Int] = [50, 120, 250, 450, 700, 1_000, 1_400, 2_000, 2_800, 4_000, 6_000,
                                    7_500, 9_000, 11_000, 14_000]

    static func milestoneReward(_ m: Int) -> (gold: Double, gems: Int) {
        // gold scales with the difficulty of reaching the depth; gems are a small bump.
        // Modest one-time bonus (NOT income-replacing). Was 50*m^1.9 (depth 250 = 1.8M!),
        // which dumped millions — especially on a migrated save where every milestone
        // fired at once. Now a small, slowly-growing pickup.
        let gold = 8.0 * pow(Double(m), 1.15)
        let gems = max(1, m / 200)
        return (gold.rounded(), gems)
    }

    // HP of a block at a given depth.
    // +1.3%/m (HP doubles ~every 54 m) plus a per-zone step multiplier. Paces descent so
    // DPS must grow to go deeper — no instant dive into high-value ore (the old +0.35%/m
    // let huge DPS time-travel to billion-value zones in seconds = "billions in a minute"),
    // while staying well below the old +4.5%/m wall that hard-stalled progress.
    static func blockHP(depth: Int) -> Double {
        let d = Double(max(0, depth))
        let zone = DDMZone.zone(at: depth)
        let base = 10.0 * pow(1.020, d) + d * 2.0 + 12.0
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
        let oreChance = 0.35 + min(0.20, Double(depth) * 0.00004)
        var oreType: DDMOre? = nil
        var oreAmount: Double = 0

        if rng.chance(oreChance) && !unlocked.isEmpty {
            // bias toward the top few unlocked tiers
            let lowest = max(0, topIndex - 3)
            let pick = rng.nextInt(lowest, topIndex)
            oreType = DDMOre(rawValue: pick)
            let baseAmt = Double(rng.nextInt(1, 4))
            oreAmount = ((baseAmt + Double(depth) * 0.01) * zone.oreMult).rounded()
            if oreAmount < 1 { oreAmount = 1 }
        }

        let rubble = ((1.0 + Double(depth) * 0.04) * zone.goldMult).rounded()

        // Boss gate?
        if DDMZone.isBossDepth(depth) {
            // Boss reward scales with depth; gems give prestige a steady drip.
            let bossGold = (rubble * 6.0 + 25.0 * pow(Double(max(1, depth)), 1.05)).rounded()
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
            let tGold = (rubble * 4.0 + 12.0 * pow(Double(max(1, depth)), 1.0)).rounded()
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
