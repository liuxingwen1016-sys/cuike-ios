import ActivityKit
import Foundation

struct BrewActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var endDate: Date
        var finished: Bool
    }
    let sessionID: UUID
    let beanName: String
    let water: Int
    let startDate: Date
}
