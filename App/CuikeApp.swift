import SwiftUI
import SwiftData
import Combine

@main @MainActor struct CuikeApp: App {
    private let container: ModelContainer?
    @State private var store: BrewStore?
    private let startupError: String?

    init() {
        do {
            let schema = Schema([BeanRecord.self, RecipeRecord.self, BrewRecord.self, LibraryMetadata.self])
            let inMemory = ProcessInfo.processInfo.arguments.contains("--uitesting")
            // The widget shares only a JSON snapshot, never the private SwiftData database.
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory,
                groupContainer: .none, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let loadedStore = try BrewStore(container: container)
            self.container = container
            _store = State(initialValue: loadedStore)
            startupError = nil
        } catch {
            container = nil
            _store = State(initialValue: nil)
            startupError = error.localizedDescription
        }
    }
    var body: some Scene {
        WindowGroup {
            if let store, let container {
                RootView(store: store).modelContainer(container)
            } else {
                VStack(spacing: 24) {
                    Image(systemName: "externaldrive.badge.exclamationmark").font(.largeTitle)
                    Text("暂时无法打开本地资料").font(.title2.bold())
                    Text("原始资料已保留，应用不会自动清空数据。请重新启动后重试。")
                    if let startupError { Text(startupError).font(.caption).textSelection(.enabled) }
                }.padding(28).cuikePage()
            }
        }
    }
}

struct RootView: View {
    @Bindable var store: BrewStore
    @State private var router = AppRouter.shared
    @State private var services = SystemServices()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("completionNotification") private var completionNotification = false
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            NavigationStack { HomeView(store: store) }
                .tabItem { Label("冲煮台", systemImage: "cup.and.saucer.fill") }.tag(0)
            NavigationStack { BeanLibraryView(store: store) }
                .tabItem { Label("豆档案", systemImage: "square.stack.3d.up") }.tag(1)
            NavigationStack { JournalView(store: store) }
                .tabItem { Label("风味手记", systemImage: "book.closed") }.tag(2)
        }
        .tint(Palette.accent)
        .preferredColorScheme(appearance == "system" ? nil : appearance == "dark" ? .dark : .light)
        .sheet(item: $router.recipe, onDismiss: {
            if store.pending != nil { router.showBrew = true }
        }) { destination in
            if let recipe = store.recipe(id: destination.id) {
                NavigationStack { RecipeView(store: store, recipe: recipe, initialValues: destination.values) }
            }
        }
        .fullScreenCover(isPresented: $router.showBrew) { NavigationStack { BrewView(store: store) } }
        .alert("萃刻", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button("知道了", role: .cancel) { store.message = nil }
        } message: { Text(store.message ?? "") }
        .onOpenURL { url in
            if let route = CuikeRoute(url: url) { router.request(route); router.consume(in: store) }
        }
        .onChange(of: router.pendingRoute) { _, _ in router.consume(in: store) }
        .onChange(of: completionNotification) { _, _ in services.refreshToken += 1 }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.reconcile(); router.consume(in: store); services.refreshToken += 1 }
        }
        .onReceive(clock) { _ in if scenePhase == .active { store.reconcile() } }
        .onReceive(NotificationCenter.default.publisher(for: .cuikeSystemPreferencesChanged)) { _ in services.refreshToken += 1 }
        .task { router.consume(in: store) }
        .task(id: "\(store.revision)-\(services.refreshToken)") {
            services.publishWidget(store: store)
            await services.synchronize(session: store.pending)
        }
    }
}
