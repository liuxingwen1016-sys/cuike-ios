import Foundation
import SwiftData
import Observation

@MainActor @Observable final class BrewStore {
    private let context: ModelContext
    private var records: [BrewRecord] = []
    private var metadata: LibraryMetadata?
    private var anchor: (wall: Date, uptime: TimeInterval)?
    var beans: [BeanRecord] = []
    var recipes: [RecipeRecord] = []
    var sessions: [BrewSnapshot] = []
    var history: [HistoryItem] = []
    var revision = 0
    var message: String?
    var storageFailed = false
    var clockNeedsConfirmation = false

    init(container: ModelContainer) throws {
        context = ModelContext(container)
        context.autosaveEnabled = false
        try seedIfNeeded()
        try reload()
        reconcile()
    }

    var availableBeans: [BeanRecord] { beans.filter { !$0.archived } }
    var pending: BrewSnapshot? { sessions.first { $0.status == .running || $0.status == .awaiting } }
    var lastRecipe: RecipeRecord? {
        guard let id = metadata?.lastRecipeID else { return recipes.first }
        return recipes.first { $0.id == id }
    }
    var average: Double? { BrewStatistics.average(history.map { $0.tasting.rating }) }
    func bean(id: UUID) -> BeanRecord? { beans.first { $0.id == id } }
    func recipe(for beanID: UUID) -> RecipeRecord? { recipes.first { $0.beanID == beanID } }
    func recipe(id: UUID) -> RecipeRecord? { recipes.first { $0.id == id } }

    private func reload() throws {
        beans = try context.fetch(FetchDescriptor<BeanRecord>(sortBy: [SortDescriptor(\.createdAt)]))
        recipes = try context.fetch(FetchDescriptor<RecipeRecord>())
        records = try context.fetch(FetchDescriptor<BrewRecord>())
        metadata = try context.fetch(FetchDescriptor<LibraryMetadata>()).first
        var decoded: [BrewSnapshot] = []
        var items: [HistoryItem] = []
        for record in records {
            let snapshot = try JSONDecoder().decode(BrewSnapshot.self, from: record.snapshotData)
            try snapshot.recipe.validate()
            decoded.append(snapshot)
            if let data = record.tastingData {
                let tasting = try JSONDecoder().decode(TastingValues.self, from: data)
                try tasting.validate()
                items.append(HistoryItem(session: snapshot, tasting: tasting))
            }
        }
        guard decoded.filter({ $0.status == .running || $0.status == .awaiting }).count <= 1 else {
            throw LibraryFailure.multipleSessions
        }
        sessions = decoded
        history = items.sorted { $0.session.startedAt > $1.session.startedAt }
        revision += 1
    }

    @discardableResult private func write(_ action: () throws -> Void) -> Bool {
        guard !storageFailed else { message = LibraryFailure.unreadable.localizedDescription; return false }
        do {
            try action()
            try context.save()
            try reload()
            return true
        } catch {
            context.rollback()
            do { try reload() } catch { storageFailed = true }
            message = error.localizedDescription
            return false
        }
    }

    @discardableResult func saveBean(_ draft: BeanDraft, editing id: UUID? = nil) -> Bool {
        write {
            try draft.validate()
            if let id {
                guard let bean = bean(id: id) else { throw LibraryFailure.unreadable }
                bean.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                bean.origin = draft.origin.trimmingCharacters(in: .whitespacesAndNewlines)
                bean.process = draft.process
                bean.roast = draft.roast
                bean.color = draft.color
            } else {
                let bean = BeanRecord(draft: draft)
                context.insert(bean)
                context.insert(RecipeRecord(beanID: bean.id))
            }
        }
    }

    func setArchived(_ bean: BeanRecord, _ archived: Bool) {
        write { bean.archived = archived }
    }

    func canDelete(_ bean: BeanRecord) -> Bool {
        !bean.isSample && !sessions.contains { $0.bean.id == bean.id }
    }

    func deleteBean(_ bean: BeanRecord) {
        write {
            guard canDelete(bean) else { throw LibraryFailure.referencedBean }
            for recipe in recipes where recipe.beanID == bean.id { context.delete(recipe) }
            context.delete(bean)
        }
    }

    @discardableResult func saveRecipe(_ recipe: RecipeRecord, values: RecipeValues) -> Bool {
        write {
            try values.validate()
            guard let bean = bean(id: recipe.beanID), !bean.archived else { throw LibraryFailure.archivedBean }
            recipe.dose = values.dose
            recipe.ratio = values.ratio
            recipe.temperature = values.temperature
            recipe.updatedAt = Date()
            metadata?.lastRecipeID = recipe.id
        }
    }

    func start(_ recipe: RecipeRecord, values: RecipeValues, now: Date = Date()) -> Bool {
        let success = write {
            guard pending == nil else { throw BrewError.sessionExists }
            guard let bean = bean(id: recipe.beanID), !bean.archived else { throw LibraryFailure.archivedBean }
            let snapshot = try BrewSnapshot(bean: bean.snapshot, recipe: values, now: now)
            recipe.dose = values.dose
            recipe.ratio = values.ratio
            recipe.temperature = values.temperature
            recipe.updatedAt = now
            metadata?.lastRecipeID = recipe.id
            context.insert(try BrewRecord(snapshot: snapshot))
        }
        if success { anchor = (now, ProcessInfo.processInfo.systemUptime); clockNeedsConfirmation = false }
        return success
    }

    // A monotonic anchor detects wall-clock edits while this process is alive.
    // After cold launch only a backwards jump is detectable without a trusted clock.
    func effectiveNow(wall: Date = Date(), uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Date {
        guard let anchor, uptime >= anchor.uptime else { return wall }
        return anchor.wall.addingTimeInterval(uptime - anchor.uptime)
    }

    func reconcile(wall: Date = Date(), uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard var snapshot = pending, snapshot.status == .running, !storageFailed else { return }
        let now = effectiveNow(wall: wall, uptime: uptime)
        if abs(wall.timeIntervalSince(now)) > 5 || wall < snapshot.startedAt.addingTimeInterval(-5) {
            clockNeedsConfirmation = true
            return
        }
        if anchor == nil { anchor = (wall, uptime) }
        do {
            try snapshot.reconcile(at: now)
            if snapshot.status != .running { write { try update(snapshot) } }
        } catch { clockNeedsConfirmation = true }
    }

    private func update(_ snapshot: BrewSnapshot) throws {
        guard let record = records.first(where: { $0.id == snapshot.id }) else { throw BrewError.noSession }
        record.snapshotData = try JSONEncoder().encode(snapshot)
        record.updatedAt = Date()
    }

    @discardableResult func finish(clockAdjusted: Bool = false) -> Bool {
        let success = write {
            guard var snapshot = pending else { throw BrewError.noSession }
            try snapshot.finish(at: effectiveNow(), clockAdjusted: clockAdjusted)
            try update(snapshot)
        }
        if success { clockNeedsConfirmation = false; anchor = nil }
        return success
    }

    func discard() {
        if write({
            guard var snapshot = pending else { return }
            snapshot.status = .discarded
            snapshot.endedAt = effectiveNow()
            try update(snapshot)
        }) { clockNeedsConfirmation = false; anchor = nil }
    }

    @discardableResult func saveTasting(sessionID: UUID, values: TastingValues) -> Bool {
        write {
            try values.validate()
            guard var snapshot = sessions.first(where: { $0.id == sessionID }),
                  let record = records.first(where: { $0.id == sessionID }) else { throw BrewError.noSession }
            guard snapshot.status == .awaiting || snapshot.status == .recorded else { throw BrewError.stillRunning }
            snapshot.status = .recorded
            try update(snapshot)
            // Same record is updated on retries, so repeated taps cannot duplicate a tasting.
            record.tastingData = try JSONEncoder().encode(values)
        }
    }

    func deleteTasting(id: UUID) {
        write {
            guard let record = records.first(where: { $0.id == id }),
                  var snapshot = sessions.first(where: { $0.id == id }) else { return }
            snapshot.status = .discarded
            try update(snapshot)
            record.tastingData = nil
        }
    }

    private func seedIfNeeded() throws {
        guard try context.fetch(FetchDescriptor<LibraryMetadata>()).isEmpty else { return }
        // Never seed over a partially populated or externally restored database.
        guard try context.fetchCount(FetchDescriptor<BeanRecord>()) == 0,
              try context.fetchCount(FetchDescriptor<BrewRecord>()) == 0,
              try context.fetchCount(FetchDescriptor<RecipeRecord>()) == 0 else { throw LibraryFailure.unreadable }
        let drafts = [
            BeanDraft(name: "柑橘晨光", origin: "埃塞 · 耶加雪菲", process: "水洗", roast: "浅烘焙", color: "terracotta"),
            BeanDraft(name: "山野莓果", origin: "哥伦比亚 · 惠兰", process: "日晒", roast: "浅中烘焙", color: "sage"),
            BeanDraft(name: "雨林可可", origin: "巴西 · 喜拉多", process: "蜜处理", roast: "中烘焙", color: "cocoa")
        ]
        let meta = LibraryMetadata()
        context.insert(meta)
        let notes = ["柑橘调明亮，尾段像红茶。", "莓果香清晰，下次再冲这一份。", "坚果香和柔和的可可感。"]
        let tags = [["柑橘", "红茶"], ["莓果"], ["可可", "坚果"]]
        for (index, draft) in drafts.enumerated() {
            let bean = BeanRecord(draft: draft, isSample: true)
            context.insert(bean)
            let values = index == 1 ? RecipeValues(dose: 16, ratio: 15, temperature: 91) : RecipeValues()
            let recipe = RecipeRecord(beanID: bean.id, values: values)
            context.insert(recipe)
            if index == 0 { meta.lastRecipeID = recipe.id }
            var session = try BrewSnapshot(bean: bean.snapshot, recipe: values,
                                           now: Date(timeIntervalSince1970: 1_790_164_800 - Double(index * 86400)))
            try session.reconcile(at: session.plannedEndAt)
            session.status = .recorded
            let tasting = TastingValues(rating: [4, 5, 4][index], acidity: [4, 3, 2][index],
                                        sweetness: [3, 4, 4][index], body: [2, 3, 4][index], tags: tags[index], note: notes[index])
            context.insert(try BrewRecord(snapshot: session, tasting: tasting))
        }
        try context.save()
    }
}
