import XCTest
@testable import Nutrition


// Characterization of ProfileMetrics: Mifflin-St Jeor BMR (the +5 /
// −161 sex constants), the derived caloric goals, and the
// macroGoals(forCalories:) formula set (keto fat clamp, ratio-mode
// protein floor and carb clamp).
final class ProfileMetricsTests: XCTestCase {

    // Male, 220 lb @ 0% BF, 72", exactly 40 years old:
    //   kg = (220 × 0.453592).round(1) = 99.8
    //   cm = 72 × 2.54 = 182.88
    //   base = 99.8×9.99 + 182.88×6.25 − 40×4.92 = 1943.202
    func testBMRMaleAddsFive() {
        let p = Fixtures.ketoProfile(bodyMass: 220, gender: .male, ageYears: 40)
        XCTAssertEqual(p.caloriesBaseMetabolicRate, 1948.202, accuracy: 0.01)
    }

    func testBMRFemaleSubtracts161() {
        let p = Fixtures.ketoProfile(bodyMass: 220, gender: .female, ageYears: 40)
        XCTAssertEqual(p.caloriesBaseMetabolicRate, 1782.202, accuracy: 0.01)
    }

    func testCalorieChain() {
        var p = Fixtures.ketoProfile(bodyMass: 220, gender: .male, ageYears: 40)
        p.activeCaloriesBurned = 600
        p.calorieDeficit = 20

        let resting = 1948.202 * 1.2
        XCTAssertEqual(p.caloriesResting, resting, accuracy: 0.01)
        XCTAssertEqual(p.caloriesGoalUnadjusted, resting + 600, accuracy: 0.01)
        XCTAssertEqual(p.caloriesGoal, (resting + 600) * 0.8, accuracy: 0.01)
    }

    // ---- macroGoals(forCalories:) — keto branch ----

    private func metrics(_ p: Profile) -> ProfileMetrics { ProfileMetrics(p) }

    func testKetoGoals() {
        // LBM 100 (0% BF), ratio 1.2, carbs ceiling 20.
        let p = Fixtures.ketoProfile(bodyMass: 100, proteinRatio: 1.2, netCarbsMaximum: 20)
        let g = metrics(p).macroGoals(forCalories: 2000)

        XCTAssertEqual(g.protein, 120, accuracy: 0.0001)          // LBM × ratio
        XCTAssertEqual(g.netCarbs, 20, accuracy: 0.0001)          // stored ceiling
        // Fat absorbs the remainder: (2000 − (120+20)×4) / 9.
        XCTAssertEqual(g.fat, (2000 - 560) / 9, accuracy: 0.0001)
    }

    func testKetoFatClampedAtZero() {
        // Small caloric goal + big protein floor would go negative:
        // (500 − (120+20)×4)/9 < 0 → clamped to 0.
        let p = Fixtures.ketoProfile(bodyMass: 100, proteinRatio: 1.2, netCarbsMaximum: 20)
        let g = metrics(p).macroGoals(forCalories: 500)
        XCTAssertEqual(g.fat, 0)
    }

    // ---- macroGoals(forCalories:) — ratio branches ----

    private func ratioProfile(ratio: Double, mode: MacroMode) -> Profile {
        var p = Fixtures.ketoProfile(bodyMass: 100, proteinRatio: ratio)
        p.macroMode = mode
        return p
    }

    func testBalancedSplitWithLowProteinFloor() {
        // Balanced = 20/55/25. Floor (100 × 0.5 = 50) is below the
        // percentage protein (2000×0.20/4 = 100), so the percentage
        // wins; carbs are the remainder.
        let g = metrics(ratioProfile(ratio: 0.5, mode: .balanced)).macroGoals(forCalories: 2000)

        XCTAssertEqual(g.protein, 100, accuracy: 0.0001)
        XCTAssertEqual(g.fat, 2000 * 0.25 / 9, accuracy: 0.0001)
        // netCarbs = (2000 − 400 − fat×9)/4 = (2000 − 400 − 500)/4.
        XCTAssertEqual(g.netCarbs, 275, accuracy: 0.0001)
    }

    func testRatioModeProteinFloorWins() {
        // Floor 100×1.2 = 120 beats 2000×0.20/4 = 100; the extra
        // protein eats carbs (fat stays at the preset %).
        let g = metrics(ratioProfile(ratio: 1.2, mode: .balanced)).macroGoals(forCalories: 2000)

        XCTAssertEqual(g.protein, 120, accuracy: 0.0001)
        XCTAssertEqual(g.fat, 2000 * 0.25 / 9, accuracy: 0.0001)
        XCTAssertEqual(g.netCarbs, (2000 - 480 - 500) / 4, accuracy: 0.0001)
    }

    func testRatioModeCarbsClampedAtZero() {
        // A huge protein floor (100 × 10 = 1000 g = 4000 cal) leaves
        // negative room: carbs clamp to 0 rather than going negative.
        let g = metrics(ratioProfile(ratio: 10, mode: .balanced)).macroGoals(forCalories: 2000)

        XCTAssertEqual(g.protein, 1000, accuracy: 0.0001)
        XCTAssertEqual(g.netCarbs, 0)
    }

    // ---- goal accessors delegate to macroGoals ----

    func testGoalAccessorsMatchMacroGoals() {
        let p = Fixtures.ketoProfile(bodyMass: 100, proteinRatio: 1.2, netCarbsMaximum: 20)
        let m = metrics(p)

        XCTAssertEqual(p.proteinGoal, m.macroGoals(forCalories: p.caloriesGoal).protein, accuracy: 0.0001)
        XCTAssertEqual(p.fatGoal, m.macroGoals(forCalories: p.caloriesGoal).fat, accuracy: 0.0001)
        XCTAssertEqual(p.effectiveNetCarbsMaximum, m.macroGoals(forCalories: p.caloriesGoal).netCarbs, accuracy: 0.0001)
        XCTAssertEqual(p.fiberMinimum, (p.caloriesGoal / 1000) * 14, accuracy: 0.0001)
    }
}
