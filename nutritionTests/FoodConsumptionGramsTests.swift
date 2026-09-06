import XCTest
@testable import Nutrition


// Grams per consumption unit: the Food owns the unit, but for a
// counted unit (piece, slice, can, ...) the grams behind one unit are
// a property of the variant — a 214 g wrap and a 120 g sandwich can
// share the "Starbucks Breakfast Sandwich" Food. A variant's own
// grams win when they are expressed in the Food's counted unit;
// otherwise (gram-unit Food, unit differs, or unset) the Food's
// value applies.
final class FoodConsumptionGramsTests: XCTestCase {

    private func ingredient(_ name: String, food: String, unit: Nutrition.Unit, grams: Double, servingSize: Double) -> Ingredient {
        Ingredient(name: name, foodName: food, servingSize: servingSize,
                   calories: 100, fat: 0, fiber: 0, netCarbs: 0, protein: 0,
                   consumptionUnit: unit, consumptionGrams: grams)
    }

    private func foodMgr(unit: Nutrition.Unit, grams: Double) -> FoodMgr {
        let m = FoodMgr()
        m.foods = [Food(name: "Sandwich", type: .carbs, consumptionUnit: unit,
                        consumptionGrams: grams, currentIngredientName: "Small")]
        return m
    }

    func testVariantGramsWinInTheFoodsUnit() {
        let m = foodMgr(unit: .piece, grams: 120)
        let wrap = ingredient("Wrap", food: "Sandwich", unit: .piece, grams: 214, servingSize: 214)
        XCTAssertEqual(m.consumptionGrams(for: wrap), 214)
        XCTAssertEqual(m.consumptionUnit(for: wrap), .piece)
    }

    func testFoodGramsWinWhenVariantUnitDiffers() {
        // Gram-based Bread Food; a variant authored per slice still
        // consumes in grams (1 g per unit), like today.
        let m = FoodMgr()
        m.foods = [Food(name: "Bread", type: .carbs, consumptionUnit: .gram,
                        consumptionGrams: 1, currentIngredientName: "Loaf")]
        let slice = ingredient("Loaf", food: "Bread", unit: .slice, grams: 45, servingSize: 45)
        XCTAssertEqual(m.consumptionGrams(for: slice), 1)
        XCTAssertEqual(m.consumptionUnit(for: slice), .gram)
    }

    func testGramUnitFoodAlwaysUsesFoodGrams() {
        // A gram is a gram: the variant's stored value never applies.
        let m = foodMgr(unit: .gram, grams: 16)
        let g = ingredient("Small", food: "Sandwich", unit: .gram, grams: 1, servingSize: 32)
        XCTAssertEqual(m.consumptionGrams(for: g), 16)
    }

    func testFoodGramsWinWhenVariantHasNone() {
        let m = foodMgr(unit: .piece, grams: 120)
        let bare = ingredient("Small", food: "Sandwich", unit: .piece, grams: 0, servingSize: 120)
        XCTAssertEqual(m.consumptionGrams(for: bare), 120)
    }

    func testOnePieceOfAVariantIsOneServingOfItself() {
        // The whole point: one wrap = its own serving, so a meal row
        // of 1 piece yields the label calories, not 120/214 of them.
        let env = SolverEnv(
            ingredients: [ingredient("Wrap", food: "Sandwich", unit: .piece, grams: 214, servingSize: 214)],
            foods: [Food(name: "Sandwich", type: .carbs, consumptionUnit: .piece,
                         consumptionGrams: 120, currentIngredientName: "Wrap")])
        env.mealIngredientMgr.create(name: "Sandwich", amount: 1)
        env.generate()
        XCTAssertEqual(env.macrosMgr.macros.calories, 100, accuracy: 0.0001)
    }
}
