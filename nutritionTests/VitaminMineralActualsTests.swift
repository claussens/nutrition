import XCTest
@testable import Nutrition


// Pins the daily vitamin/mineral summation: every row type that
// should count (ordinary, group member, composite parts, supplement)
// does, category placeholders do not, servings scale by
// amount × consumptionGrams / servingSize, and the stored-unit →
// RDA-unit factors (vitamin D mcg → IU ×40, copper mg → mcg ×1000)
// are applied once.
final class VitaminMineralActualsTests: XCTestCase {

    private var ingredientMgr: IngredientMgr!
    private var foodMgr: FoodMgr!
    private var resolver: MealResolver!

    override func setUp() {
        super.setUp()
        var egg = Fixtures.ingredient(name: "Eggs A", food: "Eggs", servingSize: 50, consumptionGrams: 50)
        egg.vitaminD = 1          // mcg per egg → 40 IU
        egg.calcium = 28          // mg per egg
        var bread = Fixtures.ingredient(name: "Bread A", food: "Bread", servingSize: 28, consumptionGrams: 28)
        bread.calcium = 50        // mg per slice
        var d3 = Fixtures.ingredient(name: "D3", food: "D3", servingSize: 1, consumptionGrams: 1)
        d3.vitaminD = 25          // mcg per pill → 1000 IU
        d3.copper = 0.9           // mg per pill → 900 mcg

        ingredientMgr = IngredientMgr()
        ingredientMgr.ingredients = [egg, bread, d3]
        foodMgr = FoodMgr()
        foodMgr.foods = [
            Fixtures.food("Eggs", current: "Eggs A", consumptionGrams: 50),
            Fixtures.food("Bread", current: "Bread A", consumptionGrams: 28),
            Fixtures.food("D3", current: "D3", type: .supplement, consumptionGrams: 1),
        ]
        resolver = MealResolver(ingredientMgr: ingredientMgr, foodMgr: foodMgr, profile: Fixtures.ketoProfile())
    }

    private var rows: [MealIngredient] {
        [
            MealIngredient(name: "Eggs", amount: 3),                                   // 3 servings
            MealIngredient(name: "Toast", amount: 1, compositeParts: [
                MealCompositePart(foodName: "Bread", selectedVariantName: "Bread A", amount: 2),   // 2 servings
                MealCompositePart(foodName: "Eggs", selectedVariantName: "Eggs A", amount: 1),     // 1 serving
            ]),
            MealIngredient(name: "D3", amount: 2, isSupplement: true),                // 2 pills
            MealIngredient(name: "Meat", amount: 0, foodType: "meat"),                // placeholder
        ]
    }

    func testTotalsAcrossRowTypesInRDAUnits() {
        let totals = computeVitaminMineralActuals(mealIngredients: rows, resolver: resolver)

        // Vitamin D: eggs 4 × 1 mcg + D3 2 × 25 mcg = 54 mcg = 2160 IU.
        XCTAssertEqual(totals[.vitaminD] ?? 0, 2160, accuracy: 0.0001)
        // Calcium (mg, no factor): eggs 4 × 28 + bread 2 × 50 = 212.
        XCTAssertEqual(totals[.calcium] ?? 0, 212, accuracy: 0.0001)
        // Copper: 2 × 0.9 mg = 1800 mcg.
        XCTAssertEqual(totals[.copper] ?? 0, 1800, accuracy: 0.0001)
    }

    func testServingsScaleByConsumptionGramsOverServingSize() {
        // Half an egg by weight: 25 g / 50 g serving = 0.5 servings.
        let half = [MealIngredient(name: "Eggs", amount: 0.5)]
        let totals = computeVitaminMineralActuals(mealIngredients: half, resolver: resolver)
        XCTAssertEqual(totals[.calcium] ?? 0, 14, accuracy: 0.0001)
    }

    func testContributorsRankedAndPlaceholderOmitted() {
        let c = contributorsTo(nutrient: .vitaminD, mealIngredients: rows, resolver: resolver)
        XCTAssertEqual(c.map { $0.ingredientName }, ["D3", "Eggs", "Toast"])
        XCTAssertEqual(c[0].contribution, 2000, accuracy: 0.0001)
        XCTAssertEqual(c[1].contribution, 120, accuracy: 0.0001)
        XCTAssertEqual(c[2].contribution, 40, accuracy: 0.0001)
        XCTAssertEqual(c[2].consumptionUnit, .piece)
    }

    func testZeroServingSizeContributesNothing() {
        var broken = Fixtures.ingredient(name: "Broken", food: "Broken", servingSize: 0)
        broken.calcium = 100
        ingredientMgr.ingredients.append(broken)
        foodMgr.foods.append(Fixtures.food("Broken", current: "Broken"))
        let totals = computeVitaminMineralActuals(mealIngredients: [MealIngredient(name: "Broken", amount: 5)], resolver: resolver)
        XCTAssertEqual(totals[.calcium] ?? 0, 0)
    }

    func testDensityRankingAndGramsToMinimum() {
        // Per gram: egg 28/50 = 0.56 mg/g; bread 50/28 ≈ 1.79 mg/g.
        let rows = allContributorsFor(nutrient: .calcium, rdaMin: 1000, ingredientMgr: ingredientMgr)
        XCTAssertEqual(rows.map { $0.name }, ["Bread A", "Eggs A"])
        XCTAssertEqual(rows[1].perHundredGrams, 56, accuracy: 0.0001)
        XCTAssertEqual(rows[1].gramsForMin, 1000 / 0.56, accuracy: 0.0001)
    }
}
