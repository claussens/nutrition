import XCTest
@testable import Nutrition


// Pins the adjustment state machine on a meal row and the manager's
// undo paths: Manual and Automatic both restore originalAmount, an
// engine-created row is deleted on undo, Done is left alone by the
// engine, and per-100g scaling on Ingredient guards a zero serving.
final class MealIngredientAdjustmentTests: XCTestCase {

    private func mgr() -> MealIngredientMgr {
        let pid = "zzztest-" + UUID().uuidString
        let m = MealIngredientMgr(profileId: pid, profileName: pid)
        m.mealIngredients = []
        return m
    }

    func testOriginalAmountDefaultsToAmount() {
        XCTAssertEqual(MealIngredient(name: "x", amount: 3).originalAmount, 3)
        XCTAssertEqual(MealIngredient(name: "x", originalAmount: 2, amount: 3).originalAmount, 2)
    }

    func testManualAdjustmentAndUndoRestoreOriginal() {
        let m = mgr()
        m.create(name: "Cheese", amount: 2)
        let id = m.mealIngredients[0].id

        m.manualAdjustment(id: id, name: "Cheese", amount: 7)
        XCTAssertEqual(m.mealIngredients[0].amount, 7)
        XCTAssertEqual(m.mealIngredients[0].adjustment, Constants.Manual)

        m.undoManualAdjustment(id: id)
        XCTAssertEqual(m.mealIngredients[0].amount, 2)
        XCTAssertEqual(m.mealIngredients[0].adjustment, Constants.Default)
    }

    func testAutomaticAdjustmentAccumulatesAndUndoRestores() {
        let m = mgr()
        m.create(name: "Cheese", amount: 2)
        m.automaticAdjustment(name: "Cheese", amount: 1)
        m.automaticAdjustment(name: "Cheese", amount: 1)
        XCTAssertEqual(m.mealIngredients[0].amount, 4)
        XCTAssertEqual(m.mealIngredients[0].adjustment, Constants.Automatic)

        m.undoAutoAdjustments()
        XCTAssertEqual(m.mealIngredients[0].amount, 2)
        XCTAssertEqual(m.mealIngredients[0].adjustment, Constants.Default)
    }

    func testEngineCreatedRowIsDeletedOnUndo() {
        let m = mgr()
        m.automaticAdjustment(name: "Treat", amount: 3)
        XCTAssertEqual(m.mealIngredients.count, 1)
        XCTAssertEqual(m.mealIngredients[0].priorState, Constants.Ingredient)

        m.undoAutoAdjustments()
        XCTAssertTrue(m.mealIngredients.isEmpty)
    }

    func testManualAndDoneIgnoreAutomatic() {
        let manual = MealIngredient(name: "x", amount: 2, adjustment: Constants.Manual)
        XCTAssertEqual(manual.automaticAdjustment(amount: 5).amount, 2)
        let done = MealIngredient(name: "x", amount: 2, adjustment: Constants.Done)
        XCTAssertEqual(done.automaticAdjustment(amount: 5).amount, 2)
    }

    func testUndoDoneOptionallyResetsAmount() {
        let row = MealIngredient(name: "x", amount: 2).doneAdjustment(amount: 9)
        XCTAssertEqual(row.undoDoneAdjustment(resetAmount: true).amount, 2)
        XCTAssertEqual(row.undoDoneAdjustment(resetAmount: false).amount, 9)
        XCTAssertEqual(row.undoDoneAdjustment(resetAmount: false).adjustment, Constants.Default)
    }

    func testPerHundredGramScaling() {
        let i = Fixtures.ingredient(name: "a", food: "", servingSize: 50, calories: 70, fat: 5, fiber: 1, netCarbs: 2, protein: 6)
        XCTAssertEqual(i.calories100, 140, accuracy: 0.0001)
        XCTAssertEqual(i.fat100, 10, accuracy: 0.0001)
        XCTAssertEqual(i.fiber100, 2, accuracy: 0.0001)
        XCTAssertEqual(i.netCarbs100, 4, accuracy: 0.0001)
        XCTAssertEqual(i.protein100, 12, accuracy: 0.0001)

        let zero = Fixtures.ingredient(name: "z", food: "", servingSize: 0, calories: 70)
        XCTAssertEqual(zero.calories100, 0)
    }
}
