import XCTest
#if canImport(CuikeCore)
@testable import CuikeCore
#else
@testable import Cuike
#endif

final class BrewDomainTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_790_200_000)
    private var bean: BeanSnapshot { BeanSnapshot(id: UUID(), name: "柑橘晨光", origin: "埃塞", process: "水洗", roast: "浅烘焙", color: "terracotta") }
    private func session() throws -> BrewSnapshot { try BrewSnapshot(bean: bean, recipe: RecipeValues(), now: start) }

    func testWaterCalculationAndRounding() throws {
        XCTAssertEqual(RecipeValues().water, 240)
        XCTAssertEqual(RecipeValues(dose: 18).water, 288)
        XCTAssertEqual(RecipeValues(dose: 15, ratio: 15.5).water, 233)
    }
    func testAllRecipeBoundaries() throws {
        for dose in 10...30 {
            for step in 28...36 {
                let recipe = RecipeValues(dose: dose, ratio: Double(step) / 2, temperature: 85)
                XCTAssertNoThrow(try recipe.validate())
                XCTAssertGreaterThan(recipe.water, recipe.bloomWater)
            }
        }
        for recipe in [RecipeValues(dose: 9), RecipeValues(dose: 31), RecipeValues(ratio: .nan),
                       RecipeValues(ratio: 16.1), RecipeValues(temperature: 97), RecipeValues(duration: 0)] {
            XCTAssertThrowsError(try recipe.validate())
        }
    }
    func testStageBoundariesHaveNoGaps() throws {
        let session = try session()
        let cases: [(Int, BrewStage)] = [(0, .bloom), (29, .bloom), (30, .pour), (119, .pour),
                                       (120, .drawdown), (179, .drawdown), (180, .finished)]
        for (seconds, expected) in cases {
            XCTAssertEqual(session.stage(at: start.addingTimeInterval(Double(seconds))), expected)
        }
    }
    func testColdRelaunchRestoresCountdownFromEncodedTimestamp() throws {
        let encoded = try JSONEncoder().encode(session())
        var restored = try JSONDecoder().decode(BrewSnapshot.self, from: encoded)
        XCTAssertEqual(restored.remaining(at: start.addingTimeInterval(78)), 102)
        try restored.reconcile(at: start.addingTimeInterval(500))
        XCTAssertEqual(restored.status, .awaiting)
        XCTAssertEqual(restored.endedAt, start.addingTimeInterval(180))
        XCTAssertEqual(restored.actualDuration, 180)
    }
    func testEarlyFinishIsStableAndIdempotent() throws {
        var session = try session()
        try session.finish(at: start.addingTimeInterval(42))
        let finished = session
        try session.finish(at: start.addingTimeInterval(99))
        XCTAssertEqual(session, finished)
        XCTAssertEqual(session.status, .awaiting)
        XCTAssertEqual(session.endReason, .early)
        XCTAssertEqual(session.actualDuration, 42)
    }
    func testFinishingAfterDeadlineIsNotMarkedEarly() throws {
        var session = try session()
        try session.finish(at: start.addingTimeInterval(181))
        XCTAssertEqual(session.endReason, .completed)
        XCTAssertEqual(session.actualDuration, 180)
    }
    func testBackwardsClockRequiresConfirmation() throws {
        var session = try session()
        XCTAssertThrowsError(try session.reconcile(at: start.addingTimeInterval(-60))) {
            XCTAssertEqual($0 as? BrewError, .clockChanged)
        }
        XCTAssertEqual(session.status, .running)
        XCTAssertEqual(session.remaining(at: start.addingTimeInterval(-60)), 180)
        try session.finish(at: start.addingTimeInterval(-60), clockAdjusted: true)
        XCTAssertEqual(session.endReason, .clockAdjusted)
        XCTAssertEqual(session.actualDuration, 0)
    }
    func testRecipeChangesCannotMutateSessionSnapshot() throws {
        var recipe = RecipeValues()
        let session = try BrewSnapshot(bean: bean, recipe: recipe, now: start)
        recipe.dose = 18
        XCTAssertEqual(session.recipe.dose, 15)
        XCTAssertEqual(session.recipe.water, 240)
    }
    func testMeanReflectsRealRecordCountAndDeletion() {
        XCTAssertNil(BrewStatistics.average([]))
        XCTAssertEqual(BrewStatistics.average([4, 5, 4])!, 13.0/3, accuracy: 0.0001)
        XCTAssertEqual(BrewStatistics.average([4, 5, 4, 5]), 4.5)
        XCTAssertEqual(BrewStatistics.average([4, 4, 5])!, 13.0/3, accuracy: 0.0001)
    }
    func testNameAndTastingValidation() {
        XCTAssertThrowsError(try BeanDraft(name: "  \n ").validate())
        XCTAssertThrowsError(try BeanDraft(name: String(repeating: "豆", count: 41)).validate())
        XCTAssertNoThrow(try BeanDraft(name: String(repeating: "豆", count: 40)).validate())
        XCTAssertThrowsError(try TastingValues().validate())
        XCTAssertThrowsError(try TastingValues(rating: 5, note: String(repeating: "香", count: 201)).validate())
        XCTAssertNoThrow(try TastingValues(rating: 5, note: String(repeating: "香", count: 200)).validate())
    }
    func testOCRExtractionUsesOnlyExplicitFields() {
        let draft = LabelParser.parse("CUIKE COFFEE\nName: CITRUS MORNING\nOrigin: Ethiopia\nProcess: Washed\nRoast: Light\n200g")
        XCTAssertEqual(draft.name, "CITRUS MORNING")
        XCTAssertEqual(draft.origin, "Ethiopia")
        XCTAssertEqual(draft.process, "水洗")
        XCTAssertEqual(draft.roast, "浅烘焙")
        XCTAssertEqual(LabelParser.parse("埃塞 耶加雪菲 200g 日晒"), BeanDraft())
        XCTAssertEqual(LabelParser.parse("处理法：陌生文字").process, "未知")
        XCTAssertEqual(LabelParser.parse("名称：柑橘晨光").name, "柑橘晨光")
    }
    func testDeepLinksAreValidatedAndNeverStartBrew() {
        let id = UUID()
        XCTAssertEqual(CuikeRoute(url: URL(string: "cuike://recipe/\(id)")!), .recipe(id))
        XCTAssertEqual(CuikeRoute(url: URL(string: "cuike://last-recipe")!), .lastRecipe)
        XCTAssertEqual(CuikeRoute(url: URL(string: "cuike://brew/\(id)")!), .session(id))
        XCTAssertNil(CuikeRoute(url: URL(string: "https://recipe/\(id)")!))
        XCTAssertNil(CuikeRoute(url: URL(string: "cuike://recipe/invalid")!))
        XCTAssertNil(CuikeRoute(url: URL(string: "cuike://start")!))
    }
}
