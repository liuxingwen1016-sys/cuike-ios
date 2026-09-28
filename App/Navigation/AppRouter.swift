import SwiftUI
import Observation

struct RecipeDestination: Identifiable {
    let id: UUID
    var values: RecipeValues? = nil
}

@MainActor @Observable final class AppRouter {
    static let shared = AppRouter()
    var tab = 0
    var recipe: RecipeDestination?
    var showBrew = false
    var pendingRoute: CuikeRoute?
    private init() {}

    func request(_ route: CuikeRoute) { pendingRoute = route }
    func consume(in store: BrewStore) {
        guard let route = pendingRoute else { return }
        pendingRoute = nil
        switch route {
        case .lastRecipe:
            guard let item = store.lastRecipe else { tab = 0; store.message = LibraryFailure.missingRecipe.localizedDescription; return }
            openRecipe(item, store: store)
        case .recipe(let id):
            guard let item = store.recipe(id: id) else { tab = 0; store.message = LibraryFailure.missingRecipe.localizedDescription; return }
            openRecipe(item, store: store)
        case .session(let id):
            guard store.pending?.id == id else { store.message = "这杯已结束，可以在风味手记中查看。"; tab = 2; return }
            recipe = nil
            showBrew = true
        }
    }
    func openRecipe(_ item: RecipeRecord, store: BrewStore, values: RecipeValues? = nil) {
        guard store.bean(id: item.beanID)?.archived == false else { store.message = LibraryFailure.archivedBean.localizedDescription; return }
        showBrew = false
        recipe = RecipeDestination(id: item.id, values: values)
    }
}
