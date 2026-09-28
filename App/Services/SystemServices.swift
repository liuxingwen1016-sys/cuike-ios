import ActivityKit
import WidgetKit
import UserNotifications
import Observation
import OSLog

extension Notification.Name {
    static let cuikeSystemPreferencesChanged = Notification.Name("cuike.system-preferences-changed")
}

@MainActor @Observable final class SystemServices {
    var refreshToken = 0
    private let logger = Logger(subsystem: "com.cuike.brew", category: "SystemServices")
    private var publishedData: Data?

    func publishWidget(store: BrewStore) {
        let snapshot: SharedRecipeSnapshot?
        if let recipe = store.lastRecipe, let bean = store.bean(id: recipe.beanID), !bean.archived {
            snapshot = SharedRecipeSnapshot(version: 1, recipeID: recipe.id, beanName: bean.name, dose: recipe.dose,
                water: recipe.values.water, temperature: recipe.temperature, updatedAt: recipe.updatedAt)
        } else { snapshot = nil }
        let data = try? JSONEncoder().encode(snapshot)
        guard data != publishedData else { return }
        do {
            try SharedStorage.write(snapshot)
            publishedData = data
            WidgetCenter.shared.reloadTimelines(ofKind: "LastRecipeWidget")
        } catch { logger.error("Widget snapshot write failed: \(error.localizedDescription, privacy: .public)") }
    }

    func synchronize(session: BrewSnapshot?) async {
        guard !Task.isCancelled else { return }
        let center = UNUserNotificationCenter.current()
        // No server, background loop, or per-stage background haptic scheduling.
        for activity in Activity<BrewActivityAttributes>.activities {
            if activity.attributes.sessionID != session?.id || session?.status != .running {
                let state = BrewActivityAttributes.ContentState(endDate: Date(), finished: true)
                await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .immediate)
                guard !Task.isCancelled else { return }
            }
        }
        guard let session, session.status == .running else {
            center.removePendingNotificationRequests(withIdentifiers: ["brew-complete"])
            center.removeDeliveredNotifications(withIdentifiers: ["brew-complete"])
            return
        }
        guard !Task.isCancelled else { return }
        if ActivityAuthorizationInfo().areActivitiesEnabled,
           !Activity<BrewActivityAttributes>.activities.contains(where: { $0.attributes.sessionID == session.id }),
           session.plannedEndAt > Date() {
            do {
                let attributes = BrewActivityAttributes(sessionID: session.id, beanName: session.bean.name,
                    water: session.recipe.water, startDate: session.startedAt)
                _ = try Activity.request(attributes: attributes,
                    content: ActivityContent(state: BrewActivityAttributes.ContentState(endDate: session.plannedEndAt, finished: false),
                                             staleDate: session.plannedEndAt), pushType: nil)
            } catch { logger.notice("Live Activity unavailable: \(error.localizedDescription, privacy: .public)") }
        }
        let settings = await center.notificationSettings()
        guard !Task.isCancelled else { return }
        let enabled = UserDefaults.standard.bool(forKey: "completionNotification")
        guard enabled, settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional,
              session.plannedEndAt.timeIntervalSinceNow > 1 else {
            center.removePendingNotificationRequests(withIdentifiers: ["brew-complete"])
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "这一杯，时间到了"
        content.body = "\(session.bean.name) 的预设冲煮时间已结束，慢慢品尝吧。"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, session.plannedEndAt.timeIntervalSinceNow), repeats: false)
        do { try await center.add(UNNotificationRequest(identifier: "brew-complete", content: content, trigger: trigger)) }
        catch { logger.notice("Completion notification unavailable: \(error.localizedDescription, privacy: .public)") }
    }
}
