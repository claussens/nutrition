import Foundation
import XCTest
@testable import Nutrition


// Deterministic RNG (SplitMix64) so the solver's within-group
// shuffles are repeatable in tests. Same seed => same sequence.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}


enum Fixtures {

    // A keto profile whose derived goals are easy to reason about:
    // bodyFat 0% => LBM == bodyMass, so proteinGoal == bodyMass ×
    // proteinRatio exactly, and netCarbs ceiling is the stored value.
    // DOB is anchored a whole number of months before "now" so `age`
    // is stable while the tests run.
    static func ketoProfile(bodyMass: Double = 100,
                            proteinRatio: Double = 0.5,
                            netCarbsMaximum: Double = 10,
                            deficit: Int = 0,
                            gender: Gender = .male,
                            ageYears: Int = 40) -> Profile {
        Profile(name: "ZZZTest",
                dateOfBirth: Calendar.current.date(byAdding: .month, value: -12 * ageYears, to: Date())!,
                gender: gender, height: 72,
                bodyMassFromHealthKit: false, bodyMass: bodyMass,
                bodyFatPercentageFromHealthKit: false, bodyFatPercentage: 0,
                activeCaloriesBurned: 0, proteinRatio: proteinRatio,
                calorieDeficit: deficit, netCarbsMaximum: netCarbsMaximum,
                macroMode: .keto)
    }

    // Minimal ingredient: servingSize 1 + consumptionGrams 1 means
    // servings == amount, so per-unit macros are the literal values.
    static func ingredient(name: String,
                           food: String,
                           servingSize: Double = 1,
                           calories: Double = 0,
                           fat: Double = 0,
                           fiber: Double = 0,
                           netCarbs: Double = 0,
                           protein: Double = 0,
                           totalCost: Double = 0,
                           totalGrams: Double = 0,
                           consumptionGrams: Double = 1) -> Ingredient {
        Ingredient(name: name,
                   foodName: food,
                   totalCost: totalCost,
                   totalGrams: totalGrams,
                   servingSize: servingSize,
                   calories: calories,
                   fat: fat,
                   fiber: fiber,
                   netCarbs: netCarbs,
                   protein: protein,
                   consumptionGrams: consumptionGrams)
    }

    static func food(_ name: String,
                     current: String,
                     type: IngredientType = .produce,
                     consumptionGrams: Double = 1) -> Food {
        Food(name: name,
             type: type,
             consumptionUnit: .gram,
             consumptionGrams: consumptionGrams,
             currentIngredientName: current)
    }
}


// A fresh, isolated manager set for one test. Meal/adjustment data
// is namespaced under a unique random profile id, so nothing
// collides across tests (or with the test host app's own data);
// ingredient/food fixtures replace whatever the managers seeded
// from config.
struct SolverEnv {
    let ingredientMgr = IngredientMgr()
    let foodMgr = FoodMgr()
    let mealIngredientMgr: MealIngredientMgr
    let adjustmentMgr: AdjustmentMgr
    let macrosMgr = MacrosMgr()
    let profile: Profile

    init(profile: Profile = Fixtures.ketoProfile(),
         ingredients: [Ingredient] = [],
         foods: [Food] = [],
         adjustments: [Adjustment] = []) {
        let pid = "zzztest-" + UUID().uuidString
        self.profile = profile
        mealIngredientMgr = MealIngredientMgr(profileId: pid, profileName: pid)
        adjustmentMgr = AdjustmentMgr(profileId: pid)
        ingredientMgr.ingredients = ingredients
        foodMgr.foods = foods
        adjustmentMgr.adjustments = adjustments
        mealIngredientMgr.mealIngredients = []
    }

    var planner: MealPlanner {
        MealPlanner(ingredientMgr: ingredientMgr,
                    mealIngredientMgr: mealIngredientMgr,
                    adjustmentMgr: adjustmentMgr,
                    macrosMgr: macrosMgr,
                    foodMgr: foodMgr,
                    profile: profile)
    }

    func generate(seed: UInt64 = 1) {
        var rng = SeededRNG(seed: seed)
        planner.generateMeal(using: &rng)
    }

    func row(_ name: String) -> MealIngredient? {
        mealIngredientMgr.getByName(name: name)
    }
}
