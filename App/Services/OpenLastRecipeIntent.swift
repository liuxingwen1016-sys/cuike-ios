import AppIntents

struct OpenLastRecipeIntent: AppIntent {
    static var title: LocalizedStringResource = "打开上次配方"
    static var description = IntentDescription("打开萃刻中上次使用的配方，由你确认后再开始冲煮。")
    static var openAppWhenRun: Bool = true

    @MainActor func perform() async throws -> some IntentResult {
        AppRouter.shared.request(.lastRecipe)
        return .result()
    }
}

struct CuikeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenLastRecipeIntent(), phrases: ["用\(.applicationName)打开上次配方", "在\(.applicationName)准备咖啡"],
                    shortTitle: "打开上次配方", systemImageName: "cup.and.saucer")
    }
}
