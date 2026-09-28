import Foundation
import SwiftData

@Model final class BeanRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var origin: String
    var process: String
    var roast: String
    var color: String
    var archived: Bool
    var isSample: Bool
    var createdAt: Date
    init(id: UUID = UUID(), draft: BeanDraft, isSample: Bool = false) {
        self.id = id
        name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        origin = draft.origin.trimmingCharacters(in: .whitespacesAndNewlines)
        process = draft.process
        roast = draft.roast
        color = draft.color
        archived = false
        self.isSample = isSample
        createdAt = Date()
    }
    var snapshot: BeanSnapshot {
        BeanSnapshot(id: id, name: name, origin: origin, process: process, roast: roast, color: color)
    }
}

@Model final class RecipeRecord {
    @Attribute(.unique) var id: UUID
    var beanID: UUID
    var dose: Int
    var ratio: Double
    var temperature: Int
    var updatedAt: Date
    init(id: UUID = UUID(), beanID: UUID, values: RecipeValues = RecipeValues()) {
        self.id = id
        self.beanID = beanID
        dose = values.dose
        ratio = values.ratio
        temperature = values.temperature
        updatedAt = Date()
    }
    var values: RecipeValues { RecipeValues(dose: dose, ratio: ratio, temperature: temperature) }
}

@Model final class BrewRecord {
    @Attribute(.unique) var id: UUID
    var snapshotData: Data
    var tastingData: Data?
    var updatedAt: Date
    init(snapshot: BrewSnapshot, tasting: TastingValues? = nil) throws {
        id = snapshot.id
        snapshotData = try JSONEncoder().encode(snapshot)
        tastingData = try tasting.map { try JSONEncoder().encode($0) }
        updatedAt = Date()
    }
}

@Model final class LibraryMetadata {
    @Attribute(.unique) var key: String
    var schemaVersion: Int
    var lastRecipeID: UUID?
    init() { key = "library"; schemaVersion = 1; lastRecipeID = nil }
}

struct HistoryItem: Identifiable {
    var id: UUID { session.id }
    let session: BrewSnapshot
    let tasting: TastingValues
}

enum LibraryFailure: LocalizedError {
    case archivedBean, referencedBean, missingRecipe, unreadable, multipleSessions
    var errorDescription: String? {
        switch self {
        case .archivedBean: return "这袋豆已归档。请先恢复档案，再准备配方。"
        case .referencedBean: return "这袋豆有冲煮记录，请使用归档保留历史。"
        case .missingRecipe: return "这份配方已不存在，请从豆档案选择一袋豆。"
        case .unreadable: return "本地资料未能读取。原始数据已保留，请重新启动应用后重试。"
        case .multipleSessions: return "检测到多条未完成会话，请先备份资料再检查数据。"
        }
    }
}
