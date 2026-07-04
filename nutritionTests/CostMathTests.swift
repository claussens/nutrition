import XCTest
@testable import Nutrition


// Characterization of the cost math: effectiveTotalGrams (explicit
// value, else grams parsed from the name), costPerGram /
// costPer100 / costPerServing, and compositeCost.
final class CostMathTests: XCTestCase {

    private func priced(name: String,
                        totalCost: Double = 0,
                        totalGrams: Double = 0,
                        servingSize: Double = 1) -> Ingredient {
        Fixtures.ingredient(name: name, food: "",
                            servingSize: servingSize,
                            totalCost: totalCost, totalGrams: totalGrams)
    }

    // ---- effectiveTotalGrams ----

    func testExplicitTotalGramsWins() {
        // A parseable "16 oz" in the name must NOT override the
        // explicit value.
        let i = priced(name: "Almonds (16 oz)", totalGrams: 500)
        XCTAssertEqual(i.effectiveTotalGrams, 500)
    }

    func testParsesOunces() {
        XCTAssertEqual(priced(name: "Almonds (16 oz)").effectiveTotalGrams,
                       16 * 28.3495, accuracy: 0.0001)
    }

    func testParsesFluidOunces() {
        // fl oz uses the same 28.3495 multiplier (weight ≈ volume).
        XCTAssertEqual(priced(name: "Cream (8 fl oz)").effectiveTotalGrams,
                       8 * 28.3495, accuracy: 0.0001)
    }

    func testParsesPounds() {
        XCTAssertEqual(priced(name: "Beef (2 lb)").effectiveTotalGrams,
                       2 * 453.592, accuracy: 0.0001)
    }

    func testParsesCountTimesServingSize() {
        XCTAssertEqual(priced(name: "Eggs (12 ct)", servingSize: 50).effectiveTotalGrams,
                       600, accuracy: 0.0001)
    }

    func testParsesPint() {
        XCTAssertEqual(priced(name: "Berries (1 pint)").effectiveTotalGrams,
                       473.176, accuracy: 0.0001)
    }

    func testParsesGrams() {
        XCTAssertEqual(priced(name: "Rice (500 g)").effectiveTotalGrams, 500, accuracy: 0.0001)
    }

    func testUnparseableNameYieldsZero() {
        XCTAssertEqual(priced(name: "Mystery Item").effectiveTotalGrams, 0)
    }

    // ---- cost derivations ----

    func testCostPerGramAndFriends() {
        let i = priced(name: "Almonds", totalCost: 10, totalGrams: 500, servingSize: 25)
        XCTAssertEqual(i.costPerGram, 0.02, accuracy: 0.000001)
        XCTAssertEqual(i.costPer100, 2.0, accuracy: 0.000001)
        XCTAssertEqual(i.costPerServing, 0.5, accuracy: 0.000001)
    }

    func testZeroGramsMeansZeroCost() {
        let i = priced(name: "Mystery", totalCost: 10)
        XCTAssertEqual(i.costPerGram, 0)
        XCTAssertEqual(i.costPerServing, 0)
    }

    // ---- compositeCost ----

    func testCompositeCostSumsPricedParts() {
        let ingredientMgr = IngredientMgr()
        ingredientMgr.ingredients = [
            // 1¢/g; consumption unit worth 26 g.
            Fixtures.ingredient(name: "Bread A", food: "Bread",
                                servingSize: 26, totalCost: 5, totalGrams: 500,
                                consumptionGrams: 26),
            // 2¢/g; consumption unit worth 16 g.
            Fixtures.ingredient(name: "PB A", food: "Peanut Butter",
                                servingSize: 32, totalCost: 8, totalGrams: 400,
                                consumptionGrams: 16),
            // Unpriced (no grams anywhere): contributes 0.
            Fixtures.ingredient(name: "Jelly A", food: "Jelly",
                                servingSize: 20, totalCost: 4),
        ]
        let foodMgr = FoodMgr()
        foodMgr.foods = [
            Fixtures.food("Bread", current: "Bread A", consumptionGrams: 26),
            Fixtures.food("Peanut Butter", current: "PB A", consumptionGrams: 16),
            Fixtures.food("Jelly", current: "Jelly A", consumptionGrams: 20),
        ]
        let mi = MealIngredient(name: "PB&J", amount: 0, compositeParts: [
            MealCompositePart(foodName: "Bread", selectedVariantName: "Bread A", amount: 2),
            MealCompositePart(foodName: "Peanut Butter", selectedVariantName: "PB A", amount: 2),
            MealCompositePart(foodName: "Jelly", selectedVariantName: "Jelly A", amount: 1),
            MealCompositePart(foodName: "Ghost", selectedVariantName: "No Such Variant", amount: 3),
        ])

        // Bread: (5/500) × 2×26 = 0.52; PB: (8/400) × 2×16 = 0.64;
        // Jelly + unknown variant: 0.
        XCTAssertEqual(compositeCost(mi, ingredientMgr, foodMgr), 0.52 + 0.64, accuracy: 0.000001)
    }
}
