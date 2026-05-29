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

    private static let saveKey = "ddm.save.v1"
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

    // --- Gem prestige multiplier (the core of the loop) ---
    // Gems give a STRONG global multiplier to BOTH damage and gold so each collapse
    // makes re-descent clearly faster. Tuned for roughly 2-4x per healthy cycle.
    // Curve: 1 + gems^0.85 * 0.55  (diminishing but always meaningful).
    var gemMultiplier: Double {
        let g = Double(max(0, save.gems))
        if g <= 0 { return 1.0 }
        let m = 1.0 + pow(g, 0.85) * 0.55
        return m.isFinite ? m : 1.0
    }

    // Permanent yield multiplier from gems + global yield boost (applies to GOLD).
    var yieldMultiplier: Double {
        let boost = 1.0 + Double(globalLevel(.yieldBoost)) * 0.15  // +15% per level
        let m = gemMultiplier * boost
        return m.isFinite ? m : 1.0
    }

    // Damage multiplier from gems + yield boost (applies to DAMAGE — tap & auto).
    var damageMultiplier: Double {
        let boost = 1.0 + Double(globalLevel(.yieldBoost)) * 0.15
        let m = gemMultiplier * boost
        return m.isFinite ? m : 1.0
    }

    // Multiplicative "milestone" bonus: x2 every 25 levels (classic-clicker style).
    private func milestoneScale(_ level: Int) -> Double {
        let steps = level / 25
        return pow(2.0, Double(steps))
    }

    // Tap (pickaxe) damage. Base per-level term * x2-every-25 * gem damage mult.
    var tapDamage: Double {
        let lvl = upgradeLevel(.pickaxe)
        let base = 1.0 + Double(lvl) * 2.0
        let d = base * milestoneScale(lvl) * damageMultiplier
        return d.isFinite ? max(1, d) : 1
    }

    // Bonus tap damage applied on top vs boss/bedrock blocks (dynamite charge).
    var burstBonusDamage: Double {
        let lvl = upgradeLevel(.dynamite)
        if lvl <= 0 { return 0 }
        let base = Double(lvl) * 8.0
        let d = base * milestoneScale(lvl) * damageMultiplier
        return d.isFinite ? max(0, d) : 0
    }

    // Auto drill damage per second. Drill count & speed each carry x2-every-25 milestones.
    var autoDPS: Double {
        let countLvl = upgradeLevel(.drillCount)
        let count = Double(countLvl) + Double(globalLevel(.autoStart)) * 2.0
        if count <= 0 { return 0 }
        let speedLvl = upgradeLevel(.drillSpeed)
        let perDrill = 1.2 * milestoneScale(countLvl)
        let speed = (1.0 + Double(speedLvl) * 0.30) * milestoneScale(speedLvl)
        let dps = count * perDrill * speed * damageMultiplier
        return dps.isFinite ? max(0, dps) : 0
    }

    // Ore sell value multiplier.
    var oreValueMultiplier: Double {
        let grader = 1.0 + Double(upgradeLevel(.oreValue)) * 0.25
        let refiner = 1.0 + Double(upgradeLevel(.refiner)) * 0.20
        let m = grader * refiner * yieldMultiplier
        return m.isFinite ? m : 1.0
    }

    // Ore drop amount multiplier (ore magnet global).
    var oreAmountMultiplier: Double {
        1.0 + Double(globalLevel(.oreMagnet)) * 0.20
    }

    // Treasure / geode find chance multiplier (prospector's eye). Extra finds on top
    // of the deterministic base geodes.
    var treasureLuckBonus: Double {
        Double(globalLevel(.treasureLuck)) * 0.25
    }

    // Cart auto-collect & auto-sell rate (ore units / second processed). 0 = manual only.
    var cartRate: Double {
        let lvl = upgradeLevel(.cart)
        if lvl <= 0 { return 0 }
        let r = Double(lvl) * 1.5 + 1.0
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

    // Estimated gold/sec from auto systems (for display).
    var goldPerSecond: Double {
        guard hasAutoSell else { return 0 }
        // approximate: dps clears HP -> blocks/sec -> ore value avg
        let hp = max(1.0, currentBlock.maxHP)
        let blocksPerSec = autoDPS / hp
        let perBlockGold = estimatedBlockGold(currentBlock)
        let g = blocksPerSec * perBlockGold
        return g.isFinite ? max(0, g) : 0
    }

    private func estimatedBlockGold(_ b: DDMBlock) -> Double {
        var g = b.rubbleGold * yieldMultiplier
        if let ore = b.oreType {
            g += b.oreAmount * ore.baseValue * oreValueMultiplier
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
        var dmg = tapDamage
        // Dynamite burst lands extra hard on bedrock bosses (and helps everywhere).
        if currentBlock.isBoss {
            dmg += burstBonusDamage * 3.0
        } else {
            dmg += burstBonusDamage
        }
        var crit = false
        if critChance > 0 {
            var rng = DDMRandom(seed: ddmSeed(save.totalTaps, save.depth &+ 7))
            if rng.chance(critChance) {
                dmg *= critMultiplier
                crit = true
            }
        }
        applyDamage(dmg, manual: true, crit: crit)
        if settings.hapticsOn {
            DDMHaptics.tap()
        }
        checkAchievements()
        throttledSaveTick(force: false)
    }

    private func applyDamage(_ amount: Double, manual: Bool, crit: Bool) {
        guard amount > 0 else { return }
        var block = currentBlock
        block.hp -= amount
        if manual {
            let hit = DDMFloatingHit(id: UUID(), text: crit ? "CRIT \(DDMFormat.number(amount))" : DDMFormat.number(amount), crit: crit)
            floatingHits.append(hit)
            if floatingHits.count > 6 { floatingHits.removeFirst(floatingHits.count - 6) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
                self?.floatingHits.removeAll { $0.id == hit.id }
            }
        }
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
            addGold(block.bonusGold * yieldMultiplier)
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
            addGold(r.gold * yieldMultiplier)
            save.gems += r.gems
        }
    }

    // MARK: - Selling

    func sellAll() {
        var earned: Double = 0
        for (raw, count) in save.oreCounts where count > 0 {
            if let ore = DDMOre(rawValue: raw) {
                earned += count * ore.baseValue * oreValueMultiplier
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
        let earned = count * ore.baseValue * oreValueMultiplier
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
                v += count * ore.baseValue * oreValueMultiplier
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
        return save.gold >= def.cost(at: lvl)
    }

    func cost(_ kind: DDMUpgradeKind) -> Double {
        DDMUpgradeDef.def(kind).cost(at: upgradeLevel(kind))
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

    // MARK: - Prestige (Collapse)

    // Gems earned from a collapse, based on THIS run's progress:
    //   depth reached this run + the *delta* of ore sold since the last collapse.
    // Repeated collapse with no new progress yields ~0 (kills the old exploit where
    // lifetimeOreSold kept paying out forever).
    var pendingGems: Int {
        let depthPart = pow(Double(max(0, save.runMaxDepth)) / 40.0, 1.45)
        let newOre = max(0, save.lifetimeOreSold - save.oreSoldClaimed)
        let orePart = pow(newOre / 2.0e4, 0.55)
        let raw = depthPart + orePart
        if !raw.isFinite || raw < 0 { return 0 }
        let g = Int(raw)
        return max(0, g)
    }

    var canCollapse: Bool {
        pendingGems > 0
    }

    func collapse() {
        let gained = pendingGems
        guard gained > 0 else { return }
        save.gems += gained
        save.totalCollapses += 1
        // Bank the ore-sold counter so re-collapse without new sales gives ~0 gems.
        save.oreSoldClaimed = save.lifetimeOreSold

        // Reset run state but keep gems, globals, achievements, lifetime totals.
        let startDepth = globalLevel(.startDepth) * 15
        save.depth = startDepth
        save.runMaxDepth = startDepth
        if startDepth > save.maxDepth { save.maxDepth = startDepth }
        save.gold = 0
        save.oreCounts = [:]
        save.currentBlockHP = -1
        // reset run upgrades (pickaxe/drills/etc.) — keep nothing run-scoped
        save.upgrades = [:]

        rebuildCurrentBlock()
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

    // Advance auto-dig and auto-sell by dt seconds.
    private func autoStep(_ dt: Double) {
        guard dt > 0 else { return }
        let dps = autoDPS
        if dps > 0 {
            var remaining = dps * dt
            // apply across possibly multiple block clears
            var guardCount = 0
            while remaining > 0 && guardCount < 5000 {
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

        // Cart auto-sell
        if hasAutoSell && totalHeldOre > 0 {
            autoSellStep(dt)
        }
    }

    private func awardBlockContents(_ block: DDMBlock) {
        addGold(block.rubbleGold * yieldMultiplier)
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
                earned += take * ore.baseValue * oreValueMultiplier
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

        let dps = autoDPS
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
        // Auto-sell remaining if cart present (so offline gold reflects sales)
        if hasAutoSell {
            // flush held ore from offline mining into gold
            sellAllSilent()
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
                earned += count * ore.baseValue * oreValueMultiplier
            }
        }
        save.oreCounts = [:]
        if earned > 0 {
            addGold(earned)
            save.lifetimeOreSold += earned
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
