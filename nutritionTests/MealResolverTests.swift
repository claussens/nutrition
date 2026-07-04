import XCTest
@testable import Nutrition


// Characterization of MealResolver's 4-step resolution order:
//   1. the row's own selectedMemberName (if it names a real ingredient)
//   2. the profile's preferred variant (profile.foodMember[foodName])
//   3. the Food's global currentIngredientName default
//   4. the literal name (plain ungrouped ingredient row)
// plus resolvedIngredient's last-ditch foodName-membership fallback.
final class MealResolverTests: XCTestCase {

    private var ingredientMgr: IngredientMgr!
    private var foodMgr: FoodMgr!

    override func setUp() {
        super.setUp()
        ingredientMgr = IngredientMgr()
        ingredientMgr.ingredients = [
            Fixtures.ingredient(name: "Eggs A", food: "Eggs", calories: 70),
            Fixtures.ingredient(name: "Eggs B", food: "Eggs", calories: 90),
            Fixtures.ingredient(name: "Plain", food: "", calories: 10),
        ]
        foodMgr = FoodMgr()
        foodMgr.foods = [Fixtures.food("Eggs", current: "Eggs A")]
    }

    private func resolver(foodMember: [String: String] = [:]) -> MealResolver {
        var profile = Fixtures.ketoProfile()
        profile.foodMember = foodMember
        return MealResolver(ingredientMgr: ingredientMgr, foodMgr: foodMgr, profile: profile)
    }

    func testRowSelectedMemberWins() {
        let mi = MealIngredient(name: "Eggs", amount: 1, selectedMemberName: "Eggs B")
        XCTAssertEqual(resolver().currentName(mi), "Eggs B")
        // ...even when the profile prefers a different variant.
        XCTAssertEqual(resolver(foodMember: ["Eggs": "Eggs A"]).currentName(mi), "Eggs B")
    }

    func testStaleRowSelectionFallsThrough() {
        let mi = MealIngredient(name: "Eggs", amount: 1, selectedMemberName: "Eggs Deleted")
        XCTAssertEqual(resolver().currentName(mi), "Eggs A")
    }

    func testProfilePreferredVariantBeatsFoodDefault() {
        let mi = MealIngredient(name: "Eggs", amount: 1)
        XCTAssertEqual(resolver(foodMember: ["Eggs": "Eggs B"]).currentName(mi), "Eggs B")
    }

    func testStaleProfilePreferenceFallsThroughToFoodDefault() {
        let mi = MealIngredient(name: "Eggs", amount: 1)
        XCTAssertEqual(resolver(foodMember: ["Eggs": "Eggs Deleted"]).currentName(mi), "Eggs A")
    }

    func testFoodCurrentIngredientDefault() {
        XCTAssertEqual(resolver().currentName(forFoodName: "Eggs"), "Eggs A")
    }

    func testLiteralNameWhenFoodCurrentDoesNotResolve() {
        // The Food exists but its currentIngredientName names nothing:
        // resolution falls to the literal name.
        foodMgr.foods = [Fixtures.food("Eggs", current: "Eggs Deleted")]
        XCTAssertEqual(resolver().currentName(forFoodName: "Eggs"), "Eggs")
    }

    func testLiteralNameForPlainUngroupedRow() {
        let mi = MealIngredient(name: "Plain", amount: 1)
        XCTAssertEqual(resolver().currentName(mi), "Plain")
        XCTAssertEqual(resolver().resolvedIngredient(mi)?.name, "Plain")
    }

    func testResolvedIngredientForGroupRow() {
        let mi = MealIngredient(name: "Eggs", amount: 1, selectedMemberName: "Eggs B")
        XCTAssertEqual(resolver().resolvedIngredient(mi)?.name, "Eggs B")
    }

    func testResolvedIngredientLastDitchFoodMembership() {
        // currentName resolves to the literal "Eggs" (no such
        // ingredient), so resolvedIngredient falls back to ANY
        // surviving member of the Food.
        foodMgr.foods = [Fixtures.food("Eggs", current: "Eggs Deleted")]
        let mi = MealIngredient(name: "Eggs", amount: 1)
        let resolved = resolver().resolvedIngredient(mi)
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.foodName, "Eggs")
    }

    func testFoodTypePlaceholderNeverResolves() {
        let mi = MealIngredient(name: "Meat", amount: 0, foodType: "meat")
        XCTAssertNil(resolver().resolvedIngredient(mi))
    }

    func testCompletelyUnknownNameResolvesToNil() {
        let mi = MealIngredient(name: "Nonexistent", amount: 1)
        XCTAssertNil(resolver().resolvedIngredient(mi))
    }
}
