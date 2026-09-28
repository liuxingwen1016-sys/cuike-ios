import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("haptics") private var haptics = true
    @AppStorage("completionNotification") private var completionNotification = false
    @State private var notificationMessage: String?
    var body: some View {
        Form {
            Section("让这一刻，更合你意") {
                Picker("外观", selection: $appearance) {
                    Text("跟随系统").tag("system"); Text("浅色").tag("light"); Text("深色").tag("dark")
                }
                Toggle("触感反馈", isOn: $haptics)
                Toggle("冲煮完成提醒", isOn: $completionNotification)
                    .onChange(of: completionNotification) { _, enabled in
                        if enabled {
                            Task {
                                do {
                                    let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                                    if !granted { completionNotification = false; notificationMessage = "通知未获授权，可以在系统设置中开启。关闭提醒也不影响冲煮。" }
                                } catch { completionNotification = false; notificationMessage = error.localizedDescription }
                                NotificationCenter.default.post(name: .cuikeSystemPreferencesChanged, object: nil)
                            }
                        } else { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["brew-complete"]) }
                    }
                if let notificationMessage { Text(notificationMessage).font(.footnote).foregroundStyle(.secondary) }
            }
            Section("系统体验") {
                Text("文字大小与减少动态效果遵循系统设置。触感只在应用前台提示；锁屏倒计时由系统显示。")
                Text("可在桌面添加萃刻小组件，或在快捷指令中选择「打开上次配方」。打开配方后，需要你点开始才会计时。")
            }.font(.subheadline)
            Section("关于萃刻") {
                Text("萃刻 · BREW MOMENTS").font(.headline)
                Text("一款离线手冲咖啡伴侣。豆档案与品饮记录保存在本机；没有账号、广告与分析上报。")
                Text("首次使用提供3袋豆和3条示例记录。相机与选图只用于文字识别，原照片不会加入档案长期保存。")
                Text("版本 1.0 · iOS 17+").font(.caption).foregroundStyle(.secondary)
            }
        }.scrollContentBackground(.hidden).cuikePage().navigationTitle("偏好设置").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
    }
}
