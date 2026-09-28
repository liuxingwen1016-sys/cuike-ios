import XCTest
import SwiftData
@testable import Cuike

@MainActor final class BrewStoreTests: XCTestCase {
    private func container(url: URL? = nil) throws -> ModelContainer {
        let schema = Schema([BeanRecord.self, RecipeRecord.self, BrewRecord.self, LibraryMetadata.self])
        let config: ModelConfiguration
        if let url { config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none) }
        else { config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none) }
        return try ModelContainer(for: schema, configurations: [config])
    }
    func testSingleSessionAndDuplicateSave() throws {
        let store = try BrewStore(container: container())
        let recipe = try XCTUnwrap(store.lastRecipe)
        XCTAssertEqual(store.history.count, 3)
        XCTAssertTrue(store.start(recipe, values: RecipeValues(dose: 18)))
        let id = try XCTUnwrap(store.pending?.id)
        XCTAssertFalse(store.start(recipe, values: RecipeValues()))
        XCTAssertEqual(store.pending?.id, id)
        XCTAssertTrue(store.finish())
        XCTAssertTrue(store.saveTasting(sessionID: id, values: TastingValues(rating: 5)))
        XCTAssertTrue(store.saveTasting(sessionID: id, values: TastingValues(rating: 5)))
        XCTAssertEqual(store.history.count, 4)
        XCTAssertEqual(store.average, 4.5)
        XCTAssertNil(store.pending)
        store.deleteTasting(id: id)
        XCTAssertEqual(store.history.count, 3)
    }
    func testHistorySurvivesBeanEditsAndArchival() throws {
        let store = try BrewStore(container: container())
        let bean = try XCTUnwrap(store.availableBeans.first)
        let original = try XCTUnwrap(store.history.first { $0.session.bean.id == bean.id })
        XCTAssertTrue(store.saveBean(BeanDraft(name: "修改后的名字"), editing: bean.id))
        XCTAssertEqual(store.history.first { $0.id == original.id }?.session.bean.name, original.session.bean.name)
        let recipe = try XCTUnwrap(store.recipe(for: bean.id))
        store.setArchived(bean, true)
        XCTAssertFalse(store.start(recipe, values: RecipeValues()))
        XCTAssertEqual(store.history.count, 3)
    }
    func testAllBeansCanBeArchivedAndNewBeanRecoversEmptyState() throws {
        let store = try BrewStore(container: container())
        for bean in store.beans { store.setArchived(bean, true) }
        XCTAssertTrue(store.availableBeans.isEmpty)
        XCTAssertTrue(store.saveBean(BeanDraft(name: "新豆")))
        let bean = try XCTUnwrap(store.availableBeans.first)
        XCTAssertNotNil(store.recipe(for: bean.id))
        XCTAssertTrue(store.canDelete(bean))
        store.deleteBean(bean)
        XCTAssertTrue(store.availableBeans.isEmpty)
    }
    func testOnDiskColdReopenKeepsSessionAndDoesNotReseed() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.store")
        var sessionID: UUID?
        do {
            let store = try BrewStore(container: container(url: url))
            let recipe = try XCTUnwrap(store.lastRecipe)
            XCTAssertTrue(store.start(recipe, values: RecipeValues(dose: 18), now: Date().addingTimeInterval(-78)))
            sessionID = store.pending?.id
        }
        let reopened = try BrewStore(container: container(url: url))
        XCTAssertEqual(reopened.pending?.id, sessionID)
        XCTAssertEqual(reopened.pending?.recipe.water, 288)
        XCTAssertEqual(reopened.history.count, 3)
        XCTAssertEqual(reopened.beans.count, 3)
    }
}
