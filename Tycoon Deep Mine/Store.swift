import SwiftUI
import Combine
import UIKit

final class DDMStore: ObservableObject {
    @Published var save = DDMSave()
    @Published var settings = DDMSettings()
    @Published var unlockedAchievements: Set<String> = []
    @Published var lastUnlocked: [String] = []

    // Transient UI state
    @Published var currentBlock: DDMBlock
    @Published var floatingHits: [DDMFloatingHit] = []
    @Published var offlineSummary: DDMOfflineSummary? = nil

    private var timer: Timer?
    private var lastTick: Date = Date()
    private var saveAccumulator: Double = 0

    // v10: ADDITIVE-COMBINING. v9 claimed "Cookie Clicker additive" but still computed
    // each composite multiplier as a PRODUCT of "additive" sub-multipliers (grader ×
    // refiner × yieldMultiplier × goldFindMultiplier). Even with each line as 1+L*0.x,
    // four products of those at L20 each = ×15, at L100 each = ×1080 — exponential in
    // the SUM of levels, hidden inside an "additive" interface. v10 collapses every
    // composite to a single bonus sum and applies it as (1 + sum) once. Per-level
    // contributions add LINEARLY across systems, no stacked exponents anywhere.
    // Pickaxe base raised to 5 (was 1) with slope 0.5/L (was 1.0/L) so the first level
    // is +10% instead of +100% — "after a couple of upgrades" no longer doubles tap.
    private static let saveKey = "ddm.save.v10"
    private static let achKey = "ddm.achievements.v1"
    private static let settingsKey = "ddm.settings.v1"

    init() {
        // temporary placeholder before load
        currentBlock = DDMWorld.block(at: 0)
        load()
        // (re)build current block
        rebuildCurrentBlock()
        creditOfflineEarnings()
        startTimer()
        observeLifecycle()
    }

    // MARK: - Derived stats

    func upgradeLevel(_ kind: DDMUpgradeKind) -> Int {
        save.upgrades[kind.rawValue] ?? 0
    }

    func globalLevel(_ kind: DDMGlobalKind) -> Int {
        save.globals[kind.rawValue] ?? 0
    }

    // --- v10: SINGLE BONUS SUMS ---
    // All "amplifier" upgrades contribute their per-level bonus to ONE sum per system
    // (gold side / damage side). Final multiplier is (1 + sum). Linear in total level
    // count, not exponential in product-of-multipliers.

    /// Sum of all gold-side per-level bonuses (applied as (1 + goldBonusSum) on gold income).
    /// Per-ore mastery is added inline in oreUnitValue(_:) since it's per-ore-type.
    var goldBonusSum: Double {
        Double(upgradeLevel(.oreValue))     * 0.08 +
        Double(upgradeLevel(.refiner))      * 0.04 +
        Double(upgradeLevel(.goldFind))     * 0.03 +
        Double(globalLevel(.yieldBoost))    * 0.10 +
        Double(metaLevel(.goldVein))        * 0.10 +
        Double(techLevel(.assayers))        * 0.06 +
        Double(max(0, save.gems))           * 0.02
    }

    /// Sum of all damage-side per-level bonuses (applied as (1 + damageBonusSum) on tap & auto).
    /// Depth-scaling contributes proportionally to current depth (capped at 200 depth-bands).
    var damageBonusSum: Double {
        let depthBands = min(200.0, Double(max(0, save.depth)) / 100.0)
        let depthContrib = Double(upgradeLevel(.depthScaling)) * 0.005 * depthBands
        return Double(globalLevel(.yieldBoost))    * 0.10 +
               Double(metaLevel(.forceCore))       * 0.10 +
               Double(techLevel(.sharpTools))      * 0.06 +
               Double(max(0, save.gems))           * 0.02 +
               depthContrib
    }

    // --- Compatibility shims for existing call sites ---
    // These properties used to be the multiplicative chains; now they return the
    // sum-based equivalent so HUD / preview code keeps compiling and showing a useful
    // number. Internal call sites have been updated to use the sums directly.
    var gemMultiplier: Double { 1.0 + Double(max(0, save.gems)) * 0.02 }
    var yieldMultiplier: Double { 1.0 + goldBonusSum }
    var damageMultiplier: Double { 1.0 + damageBonusSum }

    // Number of strikes a single tap delivers (Multi-Strike).
    var tapStrikes: Int {
        1 + upgradeLevel(.multiTap)
    }

    // Per-strike tap (pickaxe) damage. Base 5 + 0.5 per level — high enough base that
    // L0→L1 is only +10% (was +100% with base 1 + L*1). Damage bonus sum applied once.
    var tapDamage: Double {
        let lvl = upgradeLevel(.pickaxe)
        let base = 5.0 + Double(lvl) * 0.5
        let d = base * (1.0 + damageBonusSum)
        return d.isFinite ? max(1, d) : 1
    }

    // Full damage of one tap action (all strikes combined). Used for display only —
    // strikes are applied individually so HP/clears stay consistent.
    var tapDamageTotal: Double {
        let d = tapDamage * Double(tapStrikes)
        return d.isFinite ? max(1, d) : 1
    }

    // Bonus tap damage vs boss/bedrock blocks (dynamite charge). +4 dmg per level.
    var burstBonusDamage: Double {
        let lvl = upgradeLevel(.dynamite)
        if lvl <= 0 { return 0 }
        let base = Double(lvl) * 4.0
        let d = base * (1.0 + damageBonusSum)
        return d.isFinite ? max(0, d) : 0
    }

    // Auto drill damage per second. v10: per-drill contribution is itself an ADDITIVE
    // SUM (perDrill_base + speed_contrib + gearing_contrib + turbo_contrib) — no more
    // (speed × gearing × turbo) exponentiation. Damage bonus applied once at the end.
    var autoDPS: Double {
        let countLvl = upgradeLevel(.drillCount)
        let count = Double(countLvl) + Double(globalLevel(.autoStart)) * 2.0
        if count <= 0 { return 0 }
        let perDrill = 1.0 +
            Double(upgradeLevel(.drillSpeed))      * 0.10 +
            Double(upgradeLevel(.drillEfficiency)) * 0.08 +
            Double(techLevel(.turboDrills))        * 0.08
        let dps = count * perDrill * (1.0 + damageBonusSum)
        return dps.isFinite ? max(0, dps) : 0
    }

    // Auto-tapper: mechanical arm that delivers tap-strength hits automatically.
    // Each level adds 0.5 auto-taps/second; meta perk can add more.
    var autoTapRate: Double {
        let lvl = upgradeLevel(.autoTapper)
        let metaBonus = Double(metaLevel(.autoArm)) * 0.5
        let r = Double(lvl) * 0.5 + metaBonus
        return r.isFinite ? max(0, r) : 0
    }

    var autoTapDPS: Double {
        let d = autoTapRate * tapDamage
        return d.isFinite ? max(0, d) : 0
    }

    // The four properties below used to be the multiplicative chains. They now report
    // the same value the system "would" multiply by (= 1 + relevant slice of goldBonusSum)
    // so any HUD code that reads them still shows a coherent number. Internal callers
    // award gold using `(1.0 + goldBonusSum)` directly.

    var depthDamageMultiplier: Double {
        let depthBands = min(200.0, Double(max(0, save.depth)) / 100.0)
        return 1.0 + Double(upgradeLevel(.depthScaling)) * 0.005 * depthBands
    }
    var goldFindMultiplier: Double {
        1.0 + Double(upgradeLevel(.goldFind)) * 0.03 + Double(metaLevel(.goldVein)) * 0.10
    }
    var oreValueMultiplier: Double { 1.0 + goldBonusSum }
    func oreMasteryMultiplier(_ ore: DDMOre) -> Double {
        let lvl = save.oreMastery[ore.rawValue] ?? 0
        return 1.0 + Double(lvl) * 0.05
    }

    // Per-unit ore value. Single (1 + goldBonusSum + mastery*0.05) multiplier — no
    // chains. Per-ore mastery is added inline so each ore type can have its own bonus
    // without expanding goldBonusSum.
    func oreUnitValue(_ ore: DDMOre) -> Double {
        let mastery = Double(save.oreMastery[ore.rawValue] ?? 0)
        let v = ore.baseValue * (1.0 + goldBonusSum + mastery * 0.05)
        return v.isFinite ? max(0, v) : 0
    }

    // MARK: - Meta (Cores) derived stats

    func metaLevel(_ kind: DDMMetaKind) -> Int {
        save.metaTree[kind.rawValue] ?? 0
    }

    // Global gold multiplier from the meta-tree (persists through collapse).
    var metaGoldMultiplier: Double {
        let m = 1.0 + Double(metaLevel(.goldVein)) * 0.10
        return m.isFinite ? max(1.0, m) : 1.0
    }

    var metaDamageMultiplier: Double {
        let m = 1.0 + Double(metaLevel(.forceCore)) * 0.10
        return m.isFinite ? max(1.0, m) : 1.0
    }

    // Bonus to gems gained per collapse.
    var metaGemMultiplier: Double {
        let m = 1.0 + Double(metaLevel(.gemResonance)) * 0.08
        return m.isFinite ? max(1.0, m) : 1.0
    }

    // MARK: - Research derived stats

    func techLevel(_ kind: DDMTechKind) -> Int {
        save.techs[kind.rawValue] ?? 0
    }

    var researchDamageMultiplier: Double {
        let sharp = 1.0 + Double(techLevel(.sharpTools)) * 0.06
        let turbo = 1.0 // turbo applies to auto only (handled in autoDPS gearing below)
        let m = sharp * turbo
        return m.isFinite ? max(1.0, m) : 1.0
    }

    var researchGoldMultiplier: Double {
        let assay = 1.0 + Double(techLevel(.assayers)) * 0.06
        return assay.isFinite ? max(1.0, assay) : 1.0
    }

    // Research point earn-rate multiplier (globals + meta + Field Lab).
    var researchRateMultiplier: Double {
        let lab = 1.0 + Double(globalLevel(.researchRate)) * 0.20
        let know = 1.0 + Double(metaLevel(.research)) * 0.15
        let m = lab * know
        return m.isFinite ? max(1.0, m) : 1.0
    }

    // Upgrade-cost discount from Lean Engineering (diminishing, capped ~ -36%).
    var upgradeCostMultiplier: Double {
        let lvl = techLevel(.efficiency)
        if lvl <= 0 { return 1.0 }
        let disc = 1.0 - pow(0.99, Double(lvl)) // approaches 1 slowly; scale it
        let scaled = min(0.36, disc * 4.0)      // cap discount at 36%
        let m = 1.0 - scaled
        return m.isFinite ? max(0.5, m) : 1.0
    }

    // MARK: - Smelter derived stats

    func smelterLevel(_ kind: DDMSmelterKind) -> Int {
        save.smelterUpgrades[kind.rawValue] ?? 0
    }

    // Is the smelter unlocked at all? (any rate level)
    var hasSmelter: Bool { smelterLevel(.rate) > 0 }

    // Ore units fed into the furnace per second.
    var smeltRate: Double {
        let lvl = smelterLevel(.rate)
        if lvl <= 0 { return 0 }
        let base = Double(lvl) * 1.5
        let speed = 1.0 + Double(globalLevel(.smeltSpeed)) * 0.15 + Double(techLevel(.smelting)) * 0.20
        let r = base * speed
        return r.isFinite ? max(0, r) : 0
    }

    // Bars produced per ore unit smelted (Casting Molds).
    var barYieldPerOre: Double {
        let m = 1.0 + Double(smelterLevel(.batch)) * 0.08
        return m.isFinite ? max(1.0, m) : 1.0
    }

    // Value multiplier applied to a bar vs the raw ore unit value.
    // Bars are worth a large multiple of raw ore (the whole point of smelting), boosted
    // by Bar Purity, the Forge Heart meta perk and the Assay tech.
    func barUnitValue(_ ore: DDMOre) -> Double {
        let purity = 1.0 + Double(smelterLevel(.barValue)) * 0.12
        let forge = 1.0 + Double(metaLevel(.smelterCore)) * 0.12
        // base bar premium: 3.5x raw ore value
        let v = oreUnitValue(ore) * 3.5 * purity * forge
        return v.isFinite ? max(0, v) : 0
    }

    var totalHeldBars: Double {
        save.bars.values.reduce(0, +)
    }

    var heldBarsValue: Double {
        var v: Double = 0
        for (raw, count) in save.bars where count > 0 {
            if let ore = DDMOre(rawValue: raw) {
                v += count * barUnitValue(ore)
            }
        }
        return v
    }

    // Ore drop amount multiplier (ore magnet global + Vein Mapping tech).
    var oreAmountMultiplier: Double {
        let m = 1.0 + Double(globalLevel(.oreMagnet)) * 0.20 + Double(techLevel(.oreRichness)) * 0.10
        return m.isFinite ? max(1.0, m) : 1.0
    }

    // Treasure / geode find chance multiplier (prospector's eye + Deep Scan). Extra finds
    // on top of the deterministic base geodes.
    var treasureLuckBonus: Double {
        Double(globalLevel(.treasureLuck)) * 0.25 + Double(techLevel(.deepScan)) * 0.12
    }

    // Cart auto-collect & auto-sell rate (ore units / second processed). 0 = manual only.
    var cartRate: Double {
        let lvl = upgradeLevel(.cart)
        if lvl <= 0 { return 0 }
        let logistics = 1.0 + Double(techLevel(.logistics)) * 0.25
        let r = (Double(lvl) * 1.5 + 1.0) * logistics
        return r.isFinite ? r : 0
    }

    var hasAutoSell: Bool { upgradeLevel(.cart) > 0 }

    // Elevator depth bonus per block clear.
    var elevatorBonus: Int {
        return upgradeLevel(.elevator) // extra meters skipped per clear
    }

    // Critical tap chance.
    var critChance: Double {
        min(0.75, Double(globalLevel(.tapCrit)) * 0.03)
    }

    // Critical tap multiplier (base 5x, +1x per Detonator level).
    var critMultiplier: Double {
        5.0 + Double(globalLevel(.critPower)) * 1.0
    }

    var offlineCapSeconds: Double {
        let baseHours = 2.0 + Double(globalLevel(.offlineCap)) * 2.0
        return baseHours * 3600.0
    }

    // Estimated gold/sec from auto systems (for display + offline remainder estimate).
    var goldPerSecond: Double {
        guard hasAutoSell else { return 0 }
        // approximate: dps clears HP -> blocks/sec -> ore value avg
        let hp = max(1.0, currentBlock.maxHP)
        let blocksPerSec = (autoDPS + autoTapDPS) / hp
        var perBlockGold = estimatedBlockGold(currentBlock)
        // Smelting roughly multiplies ore value (bars worth ~3.5x); reflect it in the rate.
        if hasSmelter { perBlockGold *= 1.8 }
        let g = blocksPerSec * perBlockGold
        return g.isFinite ? max(0, g) : 0
    }

    private func estimatedBlockGold(_ b: DDMBlock) -> Double {
        let bonus = 1.0 + goldBonusSum
        var g = b.rubbleGold * bonus
        if let ore = b.oreType {
            g += b.oreAmount * oreUnitValue(ore)
        }
        return g
    }

    // MARK: - Block lifecycle

    func rebuildCurrentBlock() {
        var b = DDMWorld.block(at: save.depth)
        if save.currentBlockHP >= 0 && save.currentBlockHP <= b.maxHP {
            b.hp = save.currentBlockHP
        }
        currentBlock = b
        save.currentBlockHP = b.hp
    }

    // MARK: - Tapping

    func tapDig() {
        save.totalTaps += 1
        let strikes = tapStrikes
        var perStrike = tapDamage
        // Dynamite burst lands extra hard on bedrock bosses (and helps everywhere).
        if currentBlock.isBoss {
            perStrike += burstBonusDamage * 3.0
        } else {
            perStrike += burstBonusDamage
        }
        var crit = false
        if critChance > 0 {
            var rng = DDMRandom(seed: ddmSeed(save.totalTaps, save.depth &+ 7))
            if rng.chance(critChance) {
                perStrike *= critMultiplier
                crit = true
            }
        }
        // Show the combined hit, but apply each strike individually so a multi-strike tap
        // can roll over into the next block cleanly.
        let total = perStrike * Double(max(1, strikes))
        addFloatingHit(amount: total, crit: crit)
        for _ in 0..<max(1, strikes) {
            applyDamage(perStrike, manual: false, crit: crit)
        }
        if settings.hapticsOn {
            DDMHaptics.tap()
        }
        checkAchievements()
        throttledSaveTick(force: false)
    }

    private func addFloatingHit(amount: Double, crit: Bool) {
        let hit = DDMFloatingHit(id: UUID(), text: crit ? "CRIT \(DDMFormat.number(amount))" : DDMFormat.number(amount), crit: crit)
        floatingHits.append(hit)
        if floatingHits.count > 6 { floatingHits.removeFirst(floatingHits.count - 6) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            self?.floatingHits.removeAll { $0.id == hit.id }
        }
    }

    private func applyDamage(_ amount: Double, manual: Bool, crit: Bool) {
        guard amount > 0 else { return }
        var block = currentBlock
        block.hp -= amount
        if block.hp <= 0 {
            clearBlock(block)
        } else {
            currentBlock = block
            save.currentBlockHP = block.hp
        }
    }

    private func clearBlock(_ block: DDMBlock) {
        awardBlockContents(block)
        // Advance depth, but never leap over a boss-gate depth.
        let advance = 1 + elevatorBonus
        save.depth = nextDepth(from: save.depth, desiredAdvance: advance)
        if save.depth > save.runMaxDepth { save.runMaxDepth = save.depth }
        if save.depth > save.maxDepth { save.maxDepth = save.depth }
        checkMilestones()
        rebuildCurrentBlock()
    }

    // Return the depth we should land on after clearing a block at `from`.
    // If the intended advance would jump over one or more boss-gate depths, stop at
    // the first one so the gate is always encountered and must be defeated.
    private func nextDepth(from current: Int, desiredAdvance: Int) -> Int {
        let target = current + desiredAdvance
        // Find the nearest boss depth in the open-closed interval (current, target].
        for z in DDMZone.all where z.endDepth != Int.max {
            let bd = z.endDepth - 1   // boss-gate depth for this zone
            if bd > current && bd <= target {
                return bd  // land exactly on the gate
            }
        }
        return target
    }

    private func mineOre(_ ore: DDMOre, amount: Double) {
        let amt = amount * oreAmountMultiplier
        let cur = save.oreCounts[ore.rawValue] ?? 0
        save.oreCounts[ore.rawValue] = cur + amt
        let mined = save.oreMinedTotals[ore.rawValue] ?? 0
        save.oreMinedTotals[ore.rawValue] = mined + amt
    }

    // Award a treasure/boss block's bonus contents. Treasure gem finds can be boosted
    // by Prospector's Eye (extra deterministic rolls).
    private func awardBonus(_ block: DDMBlock) {
        guard block.kind != .normal else { return }
        if block.bonusGold > 0 {
            addGold(block.bonusGold * (1.0 + goldBonusSum))
        }
        var gems = block.gemReward
        if block.isTreasure && treasureLuckBonus > 0 {
            // each 1.0 of luck bonus gives one extra chance at a bonus gem
            var rng = DDMRandom(seed: ddmSeed(block.depth, 0x6E37))
            var luck = treasureLuckBonus
            while luck > 0 {
                if rng.chance(min(1.0, luck)) { gems += 1 }
                luck -= 1.0
            }
        }
        if gems > 0 {
            save.gems += gems
        }
        if let bo = block.bonusOre, block.bonusOreAmount > 0 {
            mineOre(bo, amount: block.bonusOreAmount)
        }
        if block.isBoss {
            save.bossesDefeated += 1
        } else if block.isTreasure {
            save.treasuresFound += 1
        }
    }

    // One-time depth milestone rewards (gold + gems).
    private func checkMilestones() {
        for m in DDMWorld.milestones where save.maxDepth >= m {
            if save.claimedMilestones.contains(m) { continue }
            save.claimedMilestones.append(m)
            let r = DDMWorld.milestoneReward(m)
            addGold(r.gold * (1.0 + goldBonusSum))
            save.gems += r.gems
        }
        accrueResearch()
    }

    // Research Points accrue from NEW deepest depth reached (a banked basis so re-digging
    // already-explored depth pays nothing — no farming exploit). Closed-form, O(1).
    private func accrueResearch() {
        let basis = max(0, save.maxDepth)
        guard basis > save.researchClaimedDepth else { return }
        // RP for total depth = depth^1.25 * 0.5 ; pay only the delta since last basis.
        let total = pow(Double(basis), 1.25) * 0.5
        let prior = pow(Double(max(0, save.researchClaimedDepth)), 1.25) * 0.5
        var gained = (total - prior) * researchRateMultiplier
        if !gained.isFinite || gained < 0 { gained = 0 }
        if gained > 0 {
            var r = save.research + gained
            if !r.isFinite || r > 1e300 { r = 1e300 }
            save.research = r
            var lr = save.lifetimeResearch + gained
            if !lr.isFinite || lr > 1e300 { lr = 1e300 }
            save.lifetimeResearch = lr
        }
        save.researchClaimedDepth = basis
    }

    // MARK: - Selling

    func sellAll() {
        var earned: Double = 0
        for (raw, count) in save.oreCounts where count > 0 {
            if let ore = DDMOre(rawValue: raw) {
                earned += count * oreUnitValue(ore)
            }
        }
        save.oreCounts = [:]
        if earned > 0 {
            addGold(earned)
            save.lifetimeOreSold += earned
            if settings.hapticsOn { DDMHaptics.success() }
        }
        checkAchievements()
        throttledSaveTick(force: true)
    }

    func sell(_ ore: DDMOre) {
        let count = save.oreCounts[ore.rawValue] ?? 0
        guard count > 0 else { return }
        let earned = count * oreUnitValue(ore)
        save.oreCounts[ore.rawValue] = 0
        addGold(earned)
        save.lifetimeOreSold += earned
        checkAchievements()
        throttledSaveTick(force: true)
    }

    var heldOreValue: Double {
        var v: Double = 0
        for (raw, count) in save.oreCounts where count > 0 {
            if let ore = DDMOre(rawValue: raw) {
                v += count * oreUnitValue(ore)
            }
        }
        return v
    }

    var totalHeldOre: Double {
        save.oreCounts.values.reduce(0, +)
    }

    private func addGold(_ amount: Double) {
        guard amount.isFinite, amount > 0 else { return }
        var g = save.gold + amount
        if !g.isFinite || g > 1e300 { g = 1e300 }
        save.gold = g
        var life = save.lifetimeGoldEarned + amount
        if !life.isFinite || life > 1e300 { life = 1e300 }
        save.lifetimeGoldEarned = life
    }

    // MARK: - Purchases

    func canBuy(_ kind: DDMUpgradeKind) -> Bool {
        let def = DDMUpgradeDef.def(kind)
        let lvl = upgradeLevel(kind)
        if lvl >= def.maxLevel { return false }
        return save.gold >= cost(kind)
    }

    // Gold-upgrade cost with the Lean Engineering research discount applied.
    func cost(_ kind: DDMUpgradeKind) -> Double {
        let raw = DDMUpgradeDef.def(kind).cost(at: upgradeLevel(kind))
        let c = (raw * upgradeCostMultiplier).rounded()
        return c.isFinite ? max(1, c) : raw
    }

    func buy(_ kind: DDMUpgradeKind) {
        guard canBuy(kind) else { return }
        let c = cost(kind)
        save.gold -= c
        save.upgrades[kind.rawValue] = upgradeLevel(kind) + 1
        if settings.hapticsOn { DDMHaptics.tap() }
        checkAchievements()
        throttledSaveTick(force: true)
        objectWillChange.send()
    }

    func canBuyGlobal(_ kind: DDMGlobalKind) -> Bool {
        let def = DDMGlobalDef.def(kind)
        let lvl = globalLevel(kind)
        if lvl >= def.maxLevel { return false }
        return save.gems >= def.cost(at: lvl)
    }

    func globalCost(_ kind: DDMGlobalKind) -> Int {
        DDMGlobalDef.def(kind).cost(at: globalLevel(kind))
    }

    func buyGlobal(_ kind: DDMGlobalKind) {
        guard canBuyGlobal(kind) else { return }
        let c = globalCost(kind)
        save.gems -= c
        save.globals[kind.rawValue] = globalLevel(kind) + 1
        if settings.hapticsOn { DDMHaptics.success() }
        checkAchievements()
        throttledSaveTick(force: true)
        objectWillChange.send()
    }

    // --- Research techs (bought with Research Points) ---

    func techCost(_ kind: DDMTechKind) -> Double {
        DDMTechDef.def(kind).cost(at: techLevel(kind))
    }

    func canBuyTech(_ kind: DDMTechKind) -> Bool {
        let def = DDMTechDef.def(kind)
        let lvl = techLevel(kind)
        if lvl >= def.maxLevel { return false }
        return save.research >= techCost(kind)
    }

    func buyTech(_ kind: DDMTechKind) {
        guard canBuyTech(kind) else { return }
        save.research -= techCost(kind)
        if save.research < 0 { save.research = 0 }
        save.techs[kind.rawValue] = techLevel(kind) + 1
        if settings.hapticsOn { DDMHaptics.tap() }
        checkAchievements()
        throttledSaveTick(force: true)
        objectWillChange.send()
    }

    // --- Smelter upgrades (bought with Gold) ---

    func smelterCost(_ kind: DDMSmelterKind) -> Double {
        DDMSmelterDef.def(kind).cost(at: smelterLevel(kind))
    }

    func canBuySmelter(_ kind: DDMSmelterKind) -> Bool {
        let def = DDMSmelterDef.def(kind)
        let lvl = smelterLevel(kind)
        if lvl >= def.maxLevel { return false }
        return save.gold >= smelterCost(kind)
    }

    func buySmelter(_ kind: DDMSmelterKind) {
        guard canBuySmelter(kind) else { return }
        save.gold -= smelterCost(kind)
        if save.gold < 0 { save.gold = 0 }
        save.smelterUpgrades[kind.rawValue] = smelterLevel(kind) + 1
        if settings.hapticsOn { DDMHaptics.tap() }
        checkAchievements()
        throttledSaveTick(force: true)
        objectWillChange.send()
    }

    // Sell all smelted bars for gold.
    func sellAllBars() {
        var earned: Double = 0
        for (raw, count) in save.bars where count > 0 {
            if let ore = DDMOre(rawValue: raw) {
                earned += count * barUnitValue(ore)
            }
        }
        save.bars = [:]
        if earned > 0 {
            addGold(earned)
            save.lifetimeOreSold += earned
            var lb = save.lifetimeBarsValue + earned
            if !lb.isFinite || lb > 1e300 { lb = 1e300 }
            save.lifetimeBarsValue = lb
            if settings.hapticsOn { DDMHaptics.success() }
        }
        checkAchievements()
        throttledSaveTick(force: true)
    }

    // --- Per-ore mastery (bought with Gold) ---

    func oreMasteryCost(_ ore: DDMOre) -> Double {
        DDMOreMastery.cost(ore, level: save.oreMastery[ore.rawValue] ?? 0)
    }

    func canBuyMastery(_ ore: DDMOre) -> Bool {
        let lvl = save.oreMastery[ore.rawValue] ?? 0
        if lvl >= DDMOreMastery.maxLevel { return false }
        return save.gold >= oreMasteryCost(ore)
    }

    func buyMastery(_ ore: DDMOre) {
        guard canBuyMastery(ore) else { return }
        save.gold -= oreMasteryCost(ore)
        if save.gold < 0 { save.gold = 0 }
        save.oreMastery[ore.rawValue] = (save.oreMastery[ore.rawValue] ?? 0) + 1
        if settings.hapticsOn { DDMHaptics.tap() }
        checkAchievements()
        throttledSaveTick(force: true)
        objectWillChange.send()
    }

    // --- Meta perks (bought with Cores) ---

    func metaCost(_ kind: DDMMetaKind) -> Int {
        DDMMetaDef.def(kind).cost(at: metaLevel(kind))
    }

    func canBuyMeta(_ kind: DDMMetaKind) -> Bool {
        let def = DDMMetaDef.def(kind)
        let lvl = metaLevel(kind)
        if lvl >= def.maxLevel { return false }
        return save.cores >= metaCost(kind)
    }

    func buyMeta(_ kind: DDMMetaKind) {
        guard canBuyMeta(kind) else { return }
        save.cores -= metaCost(kind)
        if save.cores < 0 { save.cores = 0 }
        save.metaTree[kind.rawValue] = metaLevel(kind) + 1
        if settings.hapticsOn { DDMHaptics.success() }
        checkAchievements()
        throttledSaveTick(force: true)
        objectWillChange.send()
    }

    // MARK: - Prestige (Collapse)

    // Gems earned from a collapse, based on THIS run's progress:
    //   depth reached this run + the *delta* of ore sold since the last collapse.
    // Repeated collapse with no new progress yields ~0 (kills the old exploit where
    // lifetimeOreSold kept paying out forever).
    var pendingGems: Int {
        let depthPart = pow(Double(max(0, save.runMaxDepth)) / 40.0, 1.45)
        let newOre = max(0, save.lifetimeOreSold - save.oreSoldClaimed)
        let orePart = pow(newOre / 2.0e4, 0.55)
        let raw = (depthPart + orePart) * metaGemMultiplier
        if !raw.isFinite || raw < 0 { return 0 }
        let g = Int(raw)
        return max(0, g)
    }

    var canCollapse: Bool {
        pendingGems > 0
    }

    // The starting depth for a fresh run, including Shaft Head Start (gems) and the
    // Fault Line meta perk (cores). Clamped to keep it finite.
    var runStartDepth: Int {
        let d = globalLevel(.startDepth) * 15 + metaLevel(.deepStart) * 40
        return max(0, min(50_000, d))
    }

    // Free upgrade levels granted at run start by the Prepared Shaft meta perk.
    private func applyRunHeadStart() {
        let bonus = metaLevel(.headStart) * 5
        if bonus > 0 {
            save.upgrades[DDMUpgradeKind.pickaxe.rawValue] = bonus
            save.upgrades[DDMUpgradeKind.drillCount.rawValue] = bonus
        }
        // Seed Vault: start with a gold stake (scales modestly with level).
        let seedLevels = globalLevel(.startGold)
        if seedLevels > 0 {
            let stake = 100.0 * pow(3.0, Double(seedLevels))
            if stake.isFinite { addGold(min(stake, 1e12)) }
        }
    }

    func collapse() {
        let gained = pendingGems
        guard gained > 0 else { return }
        save.gems += gained
        save.totalCollapses += 1
        // Bank the ore-sold counter so re-collapse without new sales gives ~0 gems.
        save.oreSoldClaimed = save.lifetimeOreSold

        resetRun()
        if settings.hapticsOn { DDMHaptics.heavy() }
        checkAchievements()
        throttledSaveTick(force: true)
        objectWillChange.send()
    }

    // Reset run-scoped state (shared by Collapse and Tectonic Shift). Keeps gems, globals,
    // meta-tree, research, achievements and lifetime totals unless the caller clears them.
    private func resetRun() {
        let startDepth = runStartDepth
        save.depth = startDepth
        save.runMaxDepth = startDepth
        if startDepth > save.maxDepth { save.maxDepth = startDepth }
        save.gold = 0
        save.oreCounts = [:]
        save.bars = [:]
        save.currentBlockHP = -1
        save.upgrades = [:]
        save.smelterUpgrades = [:]   // smelter is a run-scoped gold investment
        save.oreMastery = [:]        // mastery is a run-scoped gold investment
        applyRunHeadStart()
        rebuildCurrentBlock()
    }

    // MARK: - Tectonic Shift (second prestige → Cores)

    // Cores earned from a Shift, based on BANKED prestige progress since the last shift:
    //   gems accumulated + collapses performed. Banked counters (gemsClaimedForCores /
    //   collapsesClaimedForCores) make repeat shifts with no new progress give ~0 — no
    //   farming exploit, mirroring oreSoldClaimed.
    var pendingCores: Int {
        let newGems = max(0, save.gems - save.gemsClaimedForCores)
        let newCollapses = max(0, save.totalCollapses - save.collapsesClaimedForCores)
        let gemPart = pow(Double(newGems) / 60.0, 0.62)
        let colPart = Double(newCollapses) * 0.30
        let raw = gemPart + colPart
        if !raw.isFinite || raw < 0 { return 0 }
        return max(0, Int(raw))
    }

    // Gate the shift so it can't be spammed at trivial progress.
    var canShift: Bool {
        pendingCores >= 1 && (save.gems - save.gemsClaimedForCores) >= 60
    }

    func tectonicShift() {
        let gained = pendingCores
        guard gained >= 1, canShift else { return }
        save.cores += gained
        var lc = save.lifetimeCores + gained
        if lc < 0 { lc = save.lifetimeCores }
        save.lifetimeCores = lc
        save.totalShifts += 1

        // A Shift clears gems + gem globals + the whole run, but keeps Cores, the meta-tree,
        // research + techs, achievements and lifetime totals.
        save.gems = 0
        save.globals = [:]
        // Bank the conversion basis to the POST-shift values (gems = 0, collapses = current)
        // so future gem/collapse accumulation counts toward the next shift immediately —
        // no need to re-earn the spent total, and repeat shifts at zero progress give ~0.
        save.gemsClaimedForCores = save.gems
        save.collapsesClaimedForCores = save.totalCollapses
        save.oreSoldClaimed = save.lifetimeOreSold // gems reset → next collapse basis fresh
        resetRun()

        if settings.hapticsOn { DDMHaptics.heavy() }
        checkAchievements()
        throttledSaveTick(force: true)
        objectWillChange.send()
    }

    // MARK: - Timer / auto loop

    private func startTimer() {
        lastTick = Date()
        timer?.invalidate()
        let t = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        let now = Date()
        var dt = now.timeIntervalSince(lastTick)
        lastTick = now
        if dt < 0 { dt = 0 }
        if dt > 1.0 { dt = 1.0 } // clamp huge jumps within foreground
        autoStep(dt)
        saveAccumulator += dt
        if saveAccumulator >= 5.0 {
            saveAccumulator = 0
            persist()
        }
    }

    // Advance auto-dig, auto-tap, smelting and auto-sell by dt seconds.
    private func autoStep(_ dt: Double) {
        guard dt > 0 else { return }
        // Auto-dig (drills) + auto-tap arm both feed the damage budget.
        let dps = autoDPS + autoTapDPS
        if dps > 0 {
            var remaining = dps * dt
            // Cap auto-clears per tick. Paces descent (no instant deep-dive into
            // high-value ore -> no "billions in a minute") AND prevents the old
            // 5000-clears/tick CPU lag. Overflow DPS beyond the cap is dropped this tick.
            var guardCount = 0
            while remaining > 0 && guardCount < 4 {
                guardCount += 1
                var block = currentBlock
                if remaining >= block.hp {
                    remaining -= block.hp
                    // clear silently (no floating hit)
                    awardBlockContents(block)
                    let advance = 1 + elevatorBonus
                    save.depth = nextDepth(from: save.depth, desiredAdvance: advance)
                    if save.depth > save.runMaxDepth { save.runMaxDepth = save.depth }
                    if save.depth > save.maxDepth { save.maxDepth = save.depth }
                    checkMilestones()
                    rebuildCurrentBlock()
                } else {
                    block.hp -= remaining
                    remaining = 0
                    currentBlock = block
                    save.currentBlockHP = block.hp
                }
            }
        }

        // Smelter: convert raw ore → bars (consumes ore the cart would otherwise sell raw).
        if hasSmelter && totalHeldOre > 0 {
            smeltStep(dt)
        }

        // Cart auto-sell (ore + bars)
        if hasAutoSell {
            if totalHeldOre > 0 { autoSellStep(dt) }
            if totalHeldBars > 0 { autoSellBarsStep(dt) }
        }
    }

    // Feed raw ore into the furnace, producing bars. Smelts richest ore first so the
    // valuable tiers get the premium. Bounded by smeltRate * dt.
    private func smeltStep(_ dt: Double) {
        let capacity = smeltRate * dt
        guard capacity > 0 else { return }
        var remaining = capacity
        let yield = barYieldPerOre
        for raw in save.oreCounts.keys.sorted(by: >) {
            let count = save.oreCounts[raw] ?? 0
            if count <= 0 { continue }
            let take = min(count, remaining)
            save.oreCounts[raw] = count - take
            let produced = take * yield
            save.bars[raw] = (save.bars[raw] ?? 0) + produced
            remaining -= take
            if remaining <= 0 { break }
        }
    }

    private func autoSellBarsStep(_ dt: Double) {
        // Bars sell at the same cart throughput as ore.
        let capacity = cartRate * dt
        guard capacity > 0 else { return }
        var remaining = capacity
        var earned: Double = 0
        for raw in save.bars.keys.sorted() {
            let count = save.bars[raw] ?? 0
            if count <= 0 { continue }
            let take = min(count, remaining)
            if let ore = DDMOre(rawValue: raw) {
                earned += take * barUnitValue(ore)
            }
            save.bars[raw] = count - take
            remaining -= take
            if remaining <= 0 { break }
        }
        if earned > 0 {
            addGold(earned)
            save.lifetimeOreSold += earned
            var lb = save.lifetimeBarsValue + earned
            if !lb.isFinite || lb > 1e300 { lb = 1e300 }
            save.lifetimeBarsValue = lb
        }
    }

    private func awardBlockContents(_ block: DDMBlock) {
        addGold(block.rubbleGold * (1.0 + goldBonusSum))
        if let ore = block.oreType, block.oreAmount > 0 {
            mineOre(ore, amount: block.oreAmount)
        }
        awardBonus(block)
    }

    private func autoSellStep(_ dt: Double) {
        let capacity = cartRate * dt
        guard capacity > 0 else { return }
        var remaining = capacity
        var earned: Double = 0
        // sell from cheapest first to keep valuable ore visible? sell proportionally.
        for raw in save.oreCounts.keys.sorted() {
            let count = save.oreCounts[raw] ?? 0
            if count <= 0 { continue }
            let take = min(count, remaining)
            if let ore = DDMOre(rawValue: raw) {
                earned += take * oreUnitValue(ore)
            }
            save.oreCounts[raw] = count - take
            remaining -= take
            if remaining <= 0 { break }
        }
        if earned > 0 {
            addGold(earned)
            save.lifetimeOreSold += earned
        }
    }

    // MARK: - Offline earnings

    private func creditOfflineEarnings() {
        let last = save.lastActive
        guard last > 0 else {
            save.lastActive = Date().timeIntervalSince1970
            return
        }
        let now = Date().timeIntervalSince1970
        var elapsed = now - last
        if elapsed < 30 { // ignore tiny gaps
            save.lastActive = now
            return
        }
        let capped = min(elapsed, offlineCapSeconds)
        elapsed = capped

        // Drills + the permanent auto-tap arm both progress offline.
        let dps = autoDPS + autoTapDPS
        guard dps > 0 else {
            save.lastActive = now
            return
        }

        // Simulate at coarse granularity, but cap iterations.
        let goldBefore = save.gold
        let oreBefore = save.oreMinedTotals
        let depthBefore = save.depth

        // Bounded offline simulation. Clear blocks until the time budget is spent OR a
        // hard work cap is hit, then credit any remaining time as a closed-form gold
        // estimate. This guarantees init NEVER freezes, no matter how high DPS is — the
        // old per-step loop could grind millions of clears (weak blocks x multiplicative
        // DPS) on the main thread at launch and trip the watchdog (black-screen launch).
        var timeLeft = capped
        var clears = 0
        let maxClears = 20_000
        while timeLeft > 0 && clears < maxClears {
            let hp = max(1.0, currentBlock.hp)
            let timeToClear = hp / dps
            if !timeToClear.isFinite || timeToClear > timeLeft {
                var b = currentBlock
                b.hp = max(0, b.hp - dps * timeLeft)
                currentBlock = b
                save.currentBlockHP = b.hp
                break
            }
            timeLeft -= timeToClear
            awardBlockContents(currentBlock)
            save.depth = nextDepth(from: save.depth, desiredAdvance: 1 + elevatorBonus)
            if save.depth > save.runMaxDepth { save.runMaxDepth = save.depth }
            if save.depth > save.maxDepth { save.maxDepth = save.depth }
            checkMilestones()
            rebuildCurrentBlock()
            clears += 1
        }
        // Hit the work cap with time to spare → credit the remainder as a flat estimate.
        if timeLeft > 0 && clears >= maxClears && hasAutoSell {
            let est = goldPerSecond * timeLeft
            if est.isFinite && est > 0 { addGold(est) }
        }
        // Auto-sell remaining if cart present (so offline gold reflects sales).
        if hasAutoSell {
            // If a smelter is running, convert held ore to bars first (single O(ore-types)
            // pass — bounded), then flush both ore and bars into gold.
            if hasSmelter { smeltAllSilent() }
            sellAllSilent()
            sellBarsSilent()
        }

        let goldGained = max(0, save.gold - goldBefore)
        var oreGained: Double = 0
        for (k, v) in save.oreMinedTotals {
            oreGained += v - (oreBefore[k] ?? 0)
        }
        let depthGained = save.depth - depthBefore
        save.lastActive = now

        if goldGained > 0 || oreGained > 0 || depthGained > 0 {
            offlineSummary = DDMOfflineSummary(seconds: capped,
                                               gold: goldGained,
                                               ore: oreGained,
                                               depth: depthGained,
                                               capped: (now - last) > offlineCapSeconds)
        }
    }

    private func sellAllSilent() {
        var earned: Double = 0
        for (raw, count) in save.oreCounts where count > 0 {
            if let ore = DDMOre(rawValue: raw) {
                earned += count * oreUnitValue(ore)
            }
        }
        save.oreCounts = [:]
        if earned > 0 {
            addGold(earned)
            save.lifetimeOreSold += earned
        }
    }

    // Convert ALL held ore to bars in one bounded pass (offline flush only).
    private func smeltAllSilent() {
        let yield = barYieldPerOre
        for (raw, count) in save.oreCounts where count > 0 {
            save.bars[raw] = (save.bars[raw] ?? 0) + count * yield
        }
        save.oreCounts = [:]
    }

    private func sellBarsSilent() {
        var earned: Double = 0
        for (raw, count) in save.bars where count > 0 {
            if let ore = DDMOre(rawValue: raw) {
                earned += count * barUnitValue(ore)
            }
        }
        save.bars = [:]
        if earned > 0 {
            addGold(earned)
            save.lifetimeOreSold += earned
            var lb = save.lifetimeBarsValue + earned
            if !lb.isFinite || lb > 1e300 { lb = 1e300 }
            save.lifetimeBarsValue = lb
        }
    }

    func dismissOfflineSummary() {
        offlineSummary = nil
    }

    // MARK: - Achievements

    func checkAchievements() {
        var newly: [String] = []
        for ach in DDMAchievement.all {
            if unlockedAchievements.contains(ach.id) { continue }
            if ach.evaluate(self).done {
                unlockedAchievements.insert(ach.id)
                newly.append(ach.id)
            }
        }
        if !newly.isEmpty {
            lastUnlocked = newly
            persistAchievements()
        }
    }

    var unlockedCount: Int { unlockedAchievements.count }

    // MARK: - Persistence

    private func throttledSaveTick(force: Bool) {
        if force {
            persist()
        }
    }

    func persist() {
        save.lastActive = Date().timeIntervalSince1970
        save.currentBlockHP = currentBlock.hp
        let enc = JSONEncoder()
        if let data = try? enc.encode(save) {
            UserDefaults.standard.set(data, forKey: Self.saveKey)
        }
    }

    func persistAchievements() {
        let arr = Array(unlockedAchievements)
        if let data = try? JSONEncoder().encode(arr) {
            UserDefaults.standard.set(data, forKey: Self.achKey)
        }
    }

    func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.settingsKey)
        }
    }

    private func load() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: Self.saveKey),
           let decoded = try? JSONDecoder().decode(DDMSave.self, from: data) {
            save = decoded
        }
        if let data = d.data(forKey: Self.achKey),
           let arr = try? JSONDecoder().decode([String].self, from: data) {
            unlockedAchievements = Set(arr)
        }
        if let data = d.data(forKey: Self.settingsKey),
           let decoded = try? JSONDecoder().decode(DDMSettings.self, from: data) {
            settings = decoded
        }
    }

    func resetProgress() {
        save = DDMSave()
        unlockedAchievements = []
        lastUnlocked = []
        offlineSummary = nil
        save.lastActive = Date().timeIntervalSince1970
        rebuildCurrentBlock()
        persist()
        persistAchievements()
        objectWillChange.send()
    }

    // MARK: - Lifecycle

    private func observeLifecycle() {
        NotificationCenter.default.addObserver(self, selector: #selector(onBackground),
                                               name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onForeground),
                                               name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    @objc private func onBackground() {
        persist()
    }

    @objc private func onForeground() {
        // re-credit offline progress on resume
        lastTick = Date()
        creditOfflineEarnings()
        // Immediately persist the updated lastActive so a subsequent crash or kill
        // cannot re-grant the same offline window on the next launch.
        persist()
    }
}

// MARK: - Helpers

struct DDMFloatingHit: Identifiable {
    let id: UUID
    let text: String
    let crit: Bool
}

struct DDMOfflineSummary {
    let seconds: Double
    let gold: Double
    let ore: Double
    let depth: Int
    let capped: Bool
}

enum DDMHaptics {
    static func tap() {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.impactOccurred()
    }
    static func heavy() {
        let g = UIImpactFeedbackGenerator(style: .heavy)
        g.impactOccurred()
    }
    static func success() {
        let g = UINotificationFeedbackGenerator()
        g.notificationOccurred(.success)
    }
}
