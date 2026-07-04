import XCTest
import Combine
@testable import Nutrition


// Characterization tests for the meal-generation engine
// (MealPlanner, extracted verbatim from MealList). These pin down
// CURRENT behavior — the ordering contract, the fitting rules, the
// macro bookkeeping, and the known quirks — so the Phase-2 rework
// can prove it changed nothing it didn't mean to change.
//
// The standard fixture: keto profile with LBM 100 lb and ratio 0.5
// => proteinGoal exactly 50 g; netCarbs ceiling 10 g; fatGoal large
// (fat absorbs remaining calories). Test ingredients use
// servingSize 1 / consumptionGrams 1 so servings == amount and the
// per-unit macros are the literal field values.
final class MealPlannerTests: XCTestCase {

    // ------------------------------------------------------------
    // Adjustment ordering: "[a d f]* b [c e]* g"
    // ------------------------------------------------------------

    private func orderFixture() -> SolverEnv {
        SolverEnv(adjustments: [
            Adjustment(name: "a", amount: 1, group: "g1"),
            Adjustment(name: "b", amount: 1),
            Adjustment(name: "c", amount: 1, group: "g2"),
            Adjustment(name: "d", amount: 1, group: "g1"),
            Adjustment(name: "e", amount: 1, group: "g2"),
            Adjustment(name: "f", amount: 1, group: "g1"),
            Adjustment(name: "g", amount: 1),
        ])
    }

    func testAdjustmentOrderGroupStructure() {
        let env = orderFixture()
        var rng = SeededRNG(seed: 42)
        let names = env.planner.adjustmentOrder(using: &rng).map { $0.name }

        XCTAssertEqual(names.count, 7)
        // Group g1 expands (shuffled) at the position of its first
        // member; ungrouped rules keep their list position; g2
        // likewise expands where c sits.
        XCTAssertEqual(Set(names[0...2]), ["a", "d", "f"])
        XCTAssertEqual(names[3], "b")
        XCTAssertEqual(Set(names[4...5]), ["c", "e"])
        XCTAssertEqual(names[6], "g")
    }

    func testAdjustmentOrderIsDeterministicWithSeededRNG() {
        let env = orderFixture()
        var rng1 = SeededRNG(seed: 7)
        var rng2 = SeededRNG(seed: 7)
        let names1 = env.planner.adjustmentOrder(using: &rng1).map { $0.name }
        let names2 = env.planner.adjustmentOrder(using: &rng2).map { $0.name }
        XCTAssertEqual(names1, names2)
    }

    func testAdjustmentOrderExcludesDeactivatedRulesEvenViaGroup() {
        let env = orderFixture()
        env.adjustmentMgr.deactivate("d")
        var rng = SeededRNG(seed: 42)
        let names = env.planner.adjustmentOrder(using: &rng).map { $0.name }

        XCTAssertEqual(names.count, 6)
        XCTAssertFalse(names.contains("d"))
        XCTAssertEqual(Set(names[0...1]), ["a", "f"])
        XCTAssertEqual(names[2], "b")
    }

    // ------------------------------------------------------------
    // generateMeal: repeated application until a macro goal binds
    // ------------------------------------------------------------

    // One meal row "Cheese" seeded at 2 units; rule adds 1 unit per
    // pass; each unit is 10 g protein / 100 cal. Protein goal is 50,
    // and the limit check uses strict `<` (a delta landing exactly ON
    // the goal is allowed), so the row grows 2 -> 5 and stops.
    private func proteinBoundEnv() -> SolverEnv {
        let env = SolverEnv(
            ingredients: [Fixtures.ingredient(name: "Cheese A", food: "Cheese",
                                              calories: 100, protein: 10)],
            foods: [Fixtures.food("Cheese", current: "Cheese A")],
            adjustments: [Adjustment(name: "Cheese", amount: 1)])
        env.mealIngredientMgr.create(name: "Cheese", amount: 2)
        return env
    }

    func testGenerateGrowsRowUntilProteinGoalExactlyReached() {
        let env = proteinBoundEnv()
        env.generate()

        let row = env.row("Cheese")
        XCTAssertNotNil(row)
        XCTAssertEqual(row!.amount, 5)
        XCTAssertEqual(row!.adjustment, Constants.Automatic)
        XCTAssertEqual(env.macrosMgr.macros.protein, 50, accuracy: 0.0001)
        XCTAssertEqual(env.macrosMgr.macros.calories, 500, accuracy: 0.0001)
        // The row's own running macros match the meal totals (single row).
        XCTAssertEqual(row!.protein, 50, accuracy: 0.0001)
        XCTAssertEqual(row!.calories, 500, accuracy: 0.0001)
    }

    func testGenerateIsIdempotentAcrossRegeneration() {
        let env = proteinBoundEnv()
        env.generate(seed: 1)
        env.generate(seed: 2)

        // Regeneration first undoes the auto adjustments (back to the
        // original amount 2), then reapplies them — same fixed point.
        XCTAssertEqual(env.mealIngredientMgr.mealIngredients.count, 1)
        let row = env.row("Cheese")
        XCTAssertEqual(row!.amount, 5)
        XCTAssertEqual(env.macrosMgr.macros.protein, 50, accuracy: 0.0001)
    }

    func testGenerateSetsDailyGoalsFromProfile() {
        let env = proteinBoundEnv()
        env.generate()

        // Keto profile, LBM 100 × ratio 0.5.
        XCTAssertEqual(env.macrosMgr.macros.proteinGoal, 50, accuracy: 0.0001)
        // Keto: netCarbs ceiling is the stored profile value.
        XCTAssertEqual(env.macrosMgr.macros.netCarbsMaximum, 10, accuracy: 0.0001)
        XCTAssertEqual(env.macrosMgr.macros.caloriesGoal, env.profile.caloriesGoal, accuracy: 0.0001)
        XCTAssertEqual(env.macrosMgr.macros.fatGoal, env.profile.fatGoal, accuracy: 0.0001)
    }

    // ------------------------------------------------------------
    // Adjustment-created rows
    // ------------------------------------------------------------

    func testAdjustmentCreatesMissingRowBornAutomatic() {
        // No "Treat" row in the meal; the rule adds 3 units per pass
        // (30 g protein each). First application fits (30 <= 50);
        // the second would hit 60 > 50 and is rejected.
        let env = SolverEnv(
            ingredients: [Fixtures.ingredient(name: "Treat A", food: "Treat",
                                              calories: 50, protein: 10)],
            foods: [Fixtures.food("Treat", current: "Treat A")],
            adjustments: [Adjustment(name: "Treat", amount: 3)])
        env.generate()

        let row = env.row("Treat")
        XCTAssertNotNil(row)
        XCTAssertEqual(row!.amount, 3)
        XCTAssertEqual(row!.adjustment, Constants.Automatic)
        // Born from the engine: priorState Ingredient, so regenerate
        // deletes and re-creates it instead of stacking amounts.
        XCTAssertEqual(row!.priorState, Constants.Ingredient)
        XCTAssertEqual(env.macrosMgr.macros.protein, 30, accuracy: 0.0001)

        env.generate(seed: 9)
        XCTAssertEqual(env.mealIngredientMgr.mealIngredients.filter { $0.name == "Treat" }.count, 1)
        XCTAssertEqual(env.row("Treat")!.amount, 3)
        XCTAssertEqual(env.macrosMgr.macros.protein, 30, accuracy: 0.0001)
    }

    // ------------------------------------------------------------
    // Rows the engine must not touch
    // ------------------------------------------------------------

    func testManualAndDoneRowsAreSkippedButStillCounted() {
        let env = SolverEnv(
            ingredients: [Fixtures.ingredient(name: "Cheese A", food: "Cheese",
                                              calories: 100, protein: 10)],
            foods: [Fixtures.food("Cheese", current: "Cheese A")],
            adjustments: [Adjustment(name: "Cheese", amount: 1)])
        env.mealIngredientMgr.create(name: "Cheese", amount: 4, adjustment: Constants.Manual)
        env.generate()

        let row = env.row("Cheese")
        XCTAssertEqual(row!.amount, 4)
        XCTAssertEqual(row!.adjustment, Constants.Manual)
        // Skipped by the solver, but its macros still count toward
        // the meal totals via the bulk pass.
        XCTAssertEqual(env.macrosMgr.macros.protein, 40, accuracy: 0.0001)

        // Same for Done (blue / locked).
        env.mealIngredientMgr.doneAdjustment(id: row!.id, amount: 4)
        env.generate()
        XCTAssertEqual(env.row("Cheese")!.amount, 4)
        XCTAssertEqual(env.row("Cheese")!.adjustment, Constants.Done)
    }

    // ------------------------------------------------------------
    // The maximum constraint
    // ------------------------------------------------------------

    func testMaximumConstraintCapsExistingRow() {
        // Row at 2, +1 per pass, maximum 3: one application lands
        // exactly on the cap (2+1 = 3, not > 3); the next (3+1 = 4)
        // is rejected. Protein goal is far away (0.1 g per unit).
        let env = SolverEnv(
            ingredients: [Fixtures.ingredient(name: "Cheese A", food: "Cheese",
                                              calories: 1, protein: 0.1)],
            foods: [Fixtures.food("Cheese", current: "Cheese A")],
            adjustments: [Adjustment(name: "Cheese", amount: 1, constraints: true, maximum: 3)])
        env.mealIngredientMgr.create(name: "Cheese", amount: 2)
        env.generate()

        XCTAssertEqual(env.row("Cheese")!.amount, 3)
    }

    // Phase-2 fix for the P1.1 quirk (this test deliberately replaces
    // the Phase-1 pin): the maximum constraint is now ALSO enforced
    // when the adjustment would create the row. A rule whose own
    // amount exceeds its maximum must not sneak a too-big row into
    // the meal.
    func testMaximumConstraintEnforcedWhenAdjustmentCreatesRow() {
        let env = SolverEnv(
            ingredients: [Fixtures.ingredient(name: "Treat A", food: "Treat",
                                              calories: 1, protein: 0.1)],
            foods: [Fixtures.food("Treat", current: "Treat A")],
            adjustments: [Adjustment(name: "Treat", amount: 5, constraints: true, maximum: 3)])
        env.generate()

        XCTAssertNil(env.row("Treat"))
        XCTAssertTrue(env.mealIngredientMgr.mealIngredients.isEmpty)
    }

    func testMaximumConstraintAllowsCreationWithinCap() {
        // The created-row path still applies when the rule fits its
        // own cap (amount 2 <= maximum 3), and the cap then stops
        // further growth (2+2 = 4 > 3).
        let env = SolverEnv(
            ingredients: [Fixtures.ingredient(name: "Treat A", food: "Treat",
                                              calories: 1, protein: 0.1)],
            foods: [Fixtures.food("Treat", current: "Treat A")],
            adjustments: [Adjustment(name: "Treat", amount: 2, constraints: true, maximum: 3)])
        env.generate()

        XCTAssertEqual(env.row("Treat")!.amount, 2)
    }

    // ------------------------------------------------------------
    // Macro-limit rejections (fat / netCarbs bind, not just protein)
    // ------------------------------------------------------------

    func testNetCarbsCeilingBlocksAdjustment() {
        // Each unit is 6 g netCarbs; ceiling is 10. Seeded row at 1
        // (6 g). One more unit would be 12 > 10 — rejected, so the
        // row never grows.
        let env = SolverEnv(
            ingredients: [Fixtures.ingredient(name: "Fruit A", food: "Fruit",
                                              calories: 25, netCarbs: 6)],
            foods: [Fixtures.food("Fruit", current: "Fruit A")],
            adjustments: [Adjustment(name: "Fruit", amount: 1)])
        env.mealIngredientMgr.create(name: "Fruit", amount: 1)
        env.generate()

        XCTAssertEqual(env.row("Fruit")!.amount, 1)
        XCTAssertEqual(env.macrosMgr.macros.netCarbs, 6, accuracy: 0.0001)
    }

    func testUnresolvableAdjustmentTargetIsSkipped() {
        // A rule left over for a Food with no surviving ingredient:
        // the engine must skip it (no crash, no row).
        let env = SolverEnv(adjustments: [Adjustment(name: "Ghost", amount: 1)])
        env.generate()
        XCTAssertNil(env.row("Ghost"))
        XCTAssertTrue(env.mealIngredientMgr.mealIngredients.isEmpty)
    }

    // ------------------------------------------------------------
    // Macro bookkeeping details
    // ------------------------------------------------------------

    func testServingScalingUsesFoodConsumptionGrams() {
        // servingSize 32 g, consumption unit worth 16 g => amount 4
        // is 4×16/32 = 2 servings => macros are 2× the per-serving
        // values.
        let env = SolverEnv(
            ingredients: [Fixtures.ingredient(name: "Whey A", food: "Whey",
                                              servingSize: 32,
                                              calories: 120, protein: 30)],
            foods: [Fixtures.food("Whey", current: "Whey A", consumptionGrams: 16)])
        env.mealIngredientMgr.create(name: "Whey", amount: 4)
        env.generate()

        XCTAssertEqual(env.macrosMgr.macros.calories, 240, accuracy: 0.0001)
        XCTAssertEqual(env.macrosMgr.macros.protein, 60, accuracy: 0.0001)
    }

    func testCompositeRowSumsItsParts() {
        let env = SolverEnv(
            ingredients: [
                Fixtures.ingredient(name: "Bread A", food: "Bread",
                                    servingSize: 26, calories: 60, netCarbs: 1, protein: 4,
                                    consumptionGrams: 26),
                Fixtures.ingredient(name: "PB A", food: "Peanut Butter",
                                    servingSize: 32, calories: 190, fat: 16, protein: 7,
                                    consumptionGrams: 16),
            ],
            foods: [
                Fixtures.food("Bread", current: "Bread A", consumptionGrams: 26),
                Fixtures.food("Peanut Butter", current: "PB A", consumptionGrams: 16),
            ])
        env.mealIngredientMgr.create(
            name: "PB Sandwich", amount: 0,
            adjustment: Constants.Manual,
            compositeParts: [
                MealCompositePart(foodName: "Bread", selectedVariantName: "Bread A", amount: 2),
                MealCompositePart(foodName: "Peanut Butter", selectedVariantName: "PB A", amount: 2),
            ])
        env.generate()

        // Bread: 2×26/26 = 2 servings; PB: 2×16/32 = 1 serving.
        XCTAssertEqual(env.macrosMgr.macros.calories, 2 * 60 + 190, accuracy: 0.0001)
        XCTAssertEqual(env.macrosMgr.macros.protein, 2 * 4 + 7, accuracy: 0.0001)
        XCTAssertEqual(env.macrosMgr.macros.fat, 16, accuracy: 0.0001)
        let row = env.row("PB Sandwich")!
        XCTAssertEqual(row.calories, 310, accuracy: 0.0001)
    }

    func testFoodTypePlaceholderContributesNothing() {
        let env = SolverEnv()
        env.mealIngredientMgr.mealIngredients = [
            MealIngredient(name: "Meat", amount: 0, foodType: "meat")
        ]
        env.generate()

        XCTAssertEqual(env.macrosMgr.macros.calories, 0)
        XCTAssertEqual(env.mealIngredientMgr.mealIngredients.count, 1)
    }

    // Phase-2 batching: the whole generation commits the meal rows
    // in ONE published assignment (and therefore one UserDefaults
    // serialize) instead of one per row mutation.
    func testGeneratePublishesRowsExactlyOnce() {
        let env = proteinBoundEnv()

        var publishes = 0
        let cancellable = env.mealIngredientMgr.$mealIngredients
            .dropFirst()                       // skip the current-value replay
            .sink { _ in publishes += 1 }
        env.generate()
        cancellable.cancel()

        XCTAssertEqual(publishes, 1)
        // And the committed state is the solved one.
        XCTAssertEqual(env.row("Cheese")!.amount, 5)
    }

    func testGroupRowUsesSelectedMemberForMacros() {
        // Row stored under the Food name resolves macros from ITS
        // selected member, not the Food's global default.
        let env = SolverEnv(
            ingredients: [
                Fixtures.ingredient(name: "Eggs A", food: "Eggs", calories: 70, protein: 6),
                Fixtures.ingredient(name: "Eggs B", food: "Eggs", calories: 90, protein: 8),
            ],
            foods: [Fixtures.food("Eggs", current: "Eggs A")])
        env.mealIngredientMgr.create(name: "Eggs", amount: 2, selectedMemberName: "Eggs B")
        env.generate()

        XCTAssertEqual(env.macrosMgr.macros.calories, 180, accuracy: 0.0001)
        XCTAssertEqual(env.macrosMgr.macros.protein, 16, accuracy: 0.0001)
    }
}
