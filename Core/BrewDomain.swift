import Foundation

enum BrewError: LocalizedError, Equatable {
    case invalidRecipe, invalidName, sessionExists, noSession, stillRunning, clockChanged, invalidRating

    var errorDescription: String? {
        switch self {
        case .invalidRecipe: return "请检查粉量、粉水比和水温。"
        case .invalidName: return "咖啡豆名称需要 1～40 个字。"
        case .sessionExists: return "请先完成或放弃上一杯，再开始新的冲煮。"
        case .noSession: return "这次冲煮已不存在，请返回冲煮台。"
        case .stillRunning: return "这杯还在冲煮，请先结束再留下记录。"
        case .clockChanged: return "设备时间发生变化，请确认这杯是否已结束。"
        case .invalidRating: return "请为这一杯选择 1～5 星，笔记不超过 200 字。"
        }
    }
}

struct RecipeValues: Codable, Equatable, Hashable {
    var dose: Int = 15
    var ratio: Double = 16
    var temperature: Int = 92
    var duration: Int = 180
    var water: Int { Int((Double(dose) * ratio).rounded()) }
    var bloomWater: Int { dose * 3 }

    func validate() throws {
        guard (10...30).contains(dose), ratio.isFinite, (14...18).contains(ratio),
              (ratio * 2).rounded() == ratio * 2, (85...96).contains(temperature), duration == 180 else {
            throw BrewError.invalidRecipe
        }
    }
}

struct BeanSnapshot: Codable, Equatable {
    let id: UUID
    let name: String
    let origin: String
    let process: String
    let roast: String
    let color: String
}

enum BrewStage: Int, Codable {
    case bloom, pour, drawdown, finished
    var title: String {
        switch self {
        case .bloom: return "闷蒸，唤醒香气"
        case .pour: return "缓缓注水"
        case .drawdown: return "等待滴滤"
        case .finished: return "这一杯，完成了"
        }
    }
    func instruction(recipe: RecipeValues) -> String {
        switch self {
        case .bloom: return "均匀润湿咖啡粉，注水至 \(recipe.bloomWater)g。"
        case .pour: return "细水绕圈，累计注水至 \(recipe.water)g。"
        case .drawdown: return "停止注水，让最后一滴自然落下。"
        case .finished: return "慢慢品尝，记下属于这一杯的风味。"
        }
    }
}

enum SessionStatus: String, Codable { case running, awaiting, recorded, discarded }
enum EndReason: String, Codable { case completed, early, clockAdjusted }

struct BrewSnapshot: Codable, Identifiable, Equatable {
    let id: UUID
    let bean: BeanSnapshot
    let recipe: RecipeValues
    let startedAt: Date
    let plannedEndAt: Date
    var endedAt: Date?
    var actualDuration: Int?
    var status: SessionStatus = .running
    var endReason: EndReason?

    init(id: UUID = UUID(), bean: BeanSnapshot, recipe: RecipeValues, now: Date = Date()) throws {
        try recipe.validate()
        self.id = id
        self.bean = bean
        self.recipe = recipe
        self.startedAt = now
        self.plannedEndAt = now.addingTimeInterval(TimeInterval(recipe.duration))
    }

    func elapsed(at now: Date) -> Int {
        if let actualDuration { return actualDuration }
        return min(recipe.duration, max(0, Int(now.timeIntervalSince(startedAt))))
    }
    func remaining(at now: Date) -> Int { max(0, recipe.duration - elapsed(at: now)) }
    func stage(at now: Date) -> BrewStage {
        guard status == .running else { return .finished }
        let time = elapsed(at: now)
        if time < 30 { return .bloom }
        if time < 120 { return .pour }
        return time < recipe.duration ? .drawdown : .finished
    }
    mutating func reconcile(at now: Date) throws {
        guard status == .running else { return }
        guard now >= startedAt.addingTimeInterval(-5) else { throw BrewError.clockChanged }
        if now >= plannedEndAt {
            status = .awaiting
            endedAt = plannedEndAt
            actualDuration = recipe.duration
            endReason = .completed
        }
    }
    mutating func finish(at now: Date, clockAdjusted: Bool = false) throws {
        guard status == .running else { return }
        if !clockAdjusted { try reconcile(at: now) }
        guard status == .running else { return }
        actualDuration = elapsed(at: now)
        endedAt = now
        status = .awaiting
        endReason = clockAdjusted ? .clockAdjusted : .early
    }
}

struct TastingValues: Codable, Equatable {
    var rating: Int = 0
    var acidity: Int = 3
    var sweetness: Int = 3
    var body: Int = 3
    var tags: [String] = []
    var note: String = ""
    func validate() throws {
        guard [rating, acidity, sweetness, body].allSatisfy({ (1...5).contains($0) }), note.count <= 200 else {
            throw BrewError.invalidRating
        }
    }
}

struct BeanDraft: Equatable {
    var name = ""
    var origin = ""
    var process = "未知"
    var roast = "未知"
    var color = "terracotta"
    func validate() throws {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= 40 else { throw BrewError.invalidName }
    }
}

enum LabelParser {
    // Only explicit labels are extracted. Unknown fields stay empty for confirmation.
    static func parse(_ text: String) -> BeanDraft {
        var draft = BeanDraft()
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let separator = line.firstIndex(where: { $0 == ":" || $0 == "：" }) else { continue }
            let key = line[..<separator].lowercased().trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
            guard !value.isEmpty else { continue }
            switch key {
            case "名称", "豆名", "name", "coffee": draft.name = String(value.prefix(40))
            case "产地", "origin": draft.origin = value
            case "处理法", "process":
                let map = ["washed": "水洗", "natural": "日晒", "honey": "蜜处理"]
                let normalized = map[value.lowercased()] ?? value
                if ["水洗", "日晒", "蜜处理", "厌氧", "未知"].contains(normalized) { draft.process = normalized }
            case "烘焙度", "roast":
                let map = ["light": "浅烘焙", "medium-light": "浅中烘焙", "medium": "中烘焙", "dark": "深烘焙"]
                let normalized = map[value.lowercased()] ?? value
                if ["浅烘焙", "浅中烘焙", "中烘焙", "深烘焙", "未知"].contains(normalized) { draft.roast = normalized }
            default: break
            }
        }
        return draft
    }
}

enum CuikeRoute: Equatable {
    case lastRecipe, recipe(UUID), session(UUID)
    init?(url: URL) {
        guard url.scheme?.lowercased() == "cuike" else { return nil }
        if url.host == "last-recipe" { self = .lastRecipe; return }
        guard let id = UUID(uuidString: url.lastPathComponent) else { return nil }
        switch url.host {
        case "recipe": self = .recipe(id)
        case "brew": self = .session(id)
        default: return nil
        }
    }
}

enum BrewStatistics {
    static func average(_ ratings: [Int]) -> Double? {
        guard !ratings.isEmpty else { return nil }
        return Double(ratings.reduce(0, +)) / Double(ratings.count)
    }
}
