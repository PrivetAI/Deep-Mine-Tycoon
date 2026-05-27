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

    // Permanent yield multiplier from gems + global yield boost.
    var yieldMultiplier: Double {
        let gemBonus = 1.0 + Double(save.gems) * 0.02              // each gem +2%
        let boost = 1.0 + Double(globalLevel(.yieldBoost)) * 0.08  // +8% per level
        let m = gemBonus * boost
        return m.isFinite ? m : 1.0
    }

    // Tap (pickaxe) damage.
    var tapDamage: Double {
        let lvl = upgradeLevel(.pickaxe)
        let base = 1.0 + Double(lvl) * 1.8 + pow(Double(lvl), 1.35) * 0.6
        let d = base * yieldDamageScale
        return d.isFinite ? max(1, d) : 1
    }

    // Damage scaling shouldn't get gold yield multiplier (that's for gold), but
    // depth gating makes deeper rock tough; give a mild gem-based damage assist.
    private var yieldDamageScale: Double {
        return 1.0 + Double(save.gems) * 0.01
    }

    // Auto drill damage per second.
    var autoDPS: Double {
        let count = Double(upgradeLevel(.drillCount)) + Double(globalLevel(.autoStart))
        if count <= 0 { return 0 }
        let perDrill = 0.8 + Double(upgradeLevel(.pickaxe)) * 0.25
        let speed = 1.0 + Double(upgradeLevel(.drillSpeed)) * 0.35
        let dps = count * perDrill * speed * yieldDamageScale
        return dps.isFinite ? max(0, dps) : 0
    }

    // Ore sell value multiplier.
    var oreValueMultiplier: Double {
        let grader = 1.0 + Double(upgradeLevel(.oreValue)) * 0.20
        let refiner = 1.0 + Double(upgradeLevel(.refiner)) * 0.15
        let m = grader * refiner * yieldMultiplier
        return m.isFinite ? m : 1.0
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
        var crit = false
        if critChance > 0 {
            var rng = DDMRandom(seed: ddmSeed(save.totalTaps, save.depth &+ 7))
            if rng.chance(critChance) {
                dmg *= 5.0
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
        // Award contents
        let rubble = block.rubbleGold * yieldMultiplier
        addGold(rubble)
        if let ore = block.oreType, block.oreAmount > 0 {
            mineOre(ore, amount: block.oreAmount)
        }
        // Advance depth (1 m base + elevator bonus)
        let advance = 1 + elevatorBonus
        save.depth += advance
        if save.depth > save.runMaxDepth { save.runMaxDepth = save.depth }
        if save.depth > save.maxDepth { save.maxDepth = save.depth }
        rebuildCurrentBlock()
    }

    private func mineOre(_ ore: DDMOre, amount: Double) {
        let cur = save.oreCounts[ore.rawValue] ?? 0
        save.oreCounts[ore.rawValue] = cur + amount
        let mined = save.oreMinedTotals[ore.rawValue] ?? 0
        save.oreMinedTotals[ore.rawValue] = mined + amount
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

    // Gems earned from a collapse, based on run depth + lifetime ore sold.
    var pendingGems: Int {
        let depthPart = pow(Double(save.runMaxDepth) / 50.0, 1.5)
        let orePart = pow(max(0, save.lifetimeOreSold) / 1.0e5, 0.55)
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

        // Reset run state but keep gems, globals, achievements, lifetime totals.
        let startDepth = globalLevel(.startDepth) * 10
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
                    save.depth += advance
                    if save.depth > save.runMaxDepth { save.runMaxDepth = save.depth }
                    if save.depth > save.maxDepth { save.maxDepth = save.depth }
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

        var simulated = 0.0
        let stepSize = max(0.5, capped / 4000.0)
        var iter = 0
        while simulated < capped && iter < 5000 {
            autoStep(min(stepSize, capped - simulated))
            simulated += stepSize
            iter += 1
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
