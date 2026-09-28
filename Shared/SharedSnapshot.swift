import Foundation

struct SharedRecipeSnapshot: Codable {
    let version: Int
    let recipeID: UUID
    let beanName: String
    let dose: Int
    let water: Int
    let temperature: Int
    let updatedAt: Date
    var url: URL { URL(string: "cuike://recipe/\(recipeID.uuidString)")! }
}

enum SharedStorage {
    static var groupID: String {
        Bundle.main.object(forInfoDictionaryKey: "CuikeAppGroup") as? String ?? "group.com.cuike.brew"
    }
    static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)?.appendingPathComponent("last-recipe.json")
    }
    static func read() -> SharedRecipeSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(SharedRecipeSnapshot.self, from: data), snapshot.version == 1 else { return nil }
        return snapshot
    }
    static func write(_ snapshot: SharedRecipeSnapshot?) throws {
        guard let url = fileURL else { return }
        if let snapshot { try JSONEncoder().encode(snapshot).write(to: url, options: .atomic) }
        else if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}
