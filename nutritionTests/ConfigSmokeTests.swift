import XCTest
@testable import Nutrition

// Config smoke test: the bundled YAML seed must survive the app's FULL config
// pipeline — Yams parse into the wire types, the app's referential validation,
// and the kebab→camel JSON bridge into runtime `Ingredient`s. A bundled-seed
// refresh (or a bridge/model change) that would break the app at launch fails
// here instead. Tests are hosted in Nutrition.app, so `Bundle.main` is the app
// bundle and the Config/bundled/*.yaml resources are reachable.
final class ConfigSmokeTests: XCTestCase {

    func testBundledSeedParsesAndEveryIngredientDecodes() throws {
        let data = try ConfigStore.shared.bundledConfigData()

        // Every section decoded and is non-trivially populated.
        XCTAssertFalse(data.foods.isEmpty, "bundled food.yaml decoded to zero rows")
        XCTAssertFalse(data.ingredients.isEmpty, "bundled ingredients.yaml decoded to zero rows")
        XCTAssertFalse(data.meals.isEmpty, "bundled meals.yaml decoded to zero profiles")
        XCTAssertFalse(data.rda.isEmpty, "bundled rda.yaml decoded to zero nutrients")

        // The full bridge: every config row must yield a runtime Ingredient.
        // runtimeIngredients(from:) throws naming the first offending row, so a
        // failure message points straight at the broken ingredient.
        let ingredients = try ConfigStore.shared.runtimeIngredients(from: data)
        XCTAssertEqual(ingredients.count, data.ingredients.count,
                       "bridge dropped rows: \(data.ingredients.count) config rows -> \(ingredients.count) runtime ingredients")
    }

    func testBundledSeedPassesReferentialValidation() throws {
        let data = try ConfigStore.shared.bundledConfigData()

        // The same validation ConfigSync runs before an atomic apply. At launch
        // a bundled-seed violation is only logged (an imperfect seed beats an
        // unusable app); in the test suite it should be a hard failure.
        let violations = ConfigSync.validate(data)
        XCTAssertTrue(violations.isEmpty,
                      "bundled seed has \(violations.count) validation issue(s):\n" +
                      violations.map { "  • \($0)" }.joined(separator: "\n"))
    }
}
