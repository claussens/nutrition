import Foundation


// ============================================================
// MealPlanner — the meal-generation engine (generateMeal, the
// adjustment ordering/fitting solver, and the macro bookkeeping),
// extracted from the MealList view so the solver is a plain,
// testable type. MealList keeps thin wrappers so UI call sites
// are unchanged.
//
// The generation runs on a LOCAL copy of the meal rows and macro
// totals and assigns the results back to the managers exactly once
// at the end. Previously every row mutation went through
// MealIngredientMgr, whose didSet re-encoded the whole array to
// UserDefaults — O(rows × mutations) JSON encoding per
// pull-to-refresh. One assignment = one @Published publish and one
// serialize.
//
// The RandomNumberGenerator is caller-supplied so the within-group
// shuffle in adjustmentOrder() can be made deterministic in tests
// (production passes SystemRandomNumberGenerator).
//
// `profile` is a value snapshot of the active profile taken at
// construction — same as the view reading profileMgr.profile at
// call time, since MealList constructs a fresh planner per call.
// ============================================================
struct MealPlanner {

    let ingredientMgr: IngredientMgr
    let mealIngredientMgr: MealIngredientMgr
    let adjustmentMgr: AdjustmentMgr
    let macrosMgr: MacrosMgr
    let foodMgr: FoodMgr
    let profile: Profile


    var resolver: MealResolver {
        MealResolver(ingredientMgr: ingredientMgr, foodMgr: foodMgr, profile: profile)
    }


    // The generation's working state: the meal rows and the running
    // macro totals, mutated locally and committed once.
    private struct GenerationState {
        var rows: [MealIngredient]
        var macros: Macros
    }


    func generateMeal<R: RandomNumberGenerator>(using rng: inout R) {

        // Set (or reset) the daily macro goals:
        // - reflects any changes in the manually updated profile
        // - reflects any changes to the automatically updated profile fields
        var state = GenerationState(
            rows: mealIngredientMgr.mealIngredients,
            macros: Macros().setDailyMacroGoals(caloriesGoalUnadjusted: profile.caloriesGoalUnadjusted, caloriesGoal: profile.caloriesGoal, fatGoal: profile.fatGoal, fiberMinimum: profile.fiberMinimum, netCarbsMaximum: profile.effectiveNetCarbsMaximum, proteinGoal: profile.proteinGoal))

        // Undo all the auto adjustments (so we can reapply them
        // with a clean slate).  Removal will result in:
        // 1. Meal ingredients being deleted that were added as a result of apply adjustments
        // 2. Meal ingredient amounts being set to original values
        undoAutoAdjustments(&state)

        // Initialize the total macros for each meal ingredient and
        // the total macros for all ingredients.  These will all be
        // updated later in this algorithm. The bulk pass visits
        // non-supplements first, then supplements (the manager's
        // getAllMealIngredients order).
        state.rows = state.rows.map { $0.setMacroActualsToZero() }
        let bulkOrder = state.rows.filter { !$0.isSupplement } + state.rows.filter { $0.isSupplement }
        for mealIngredient in bulkOrder {
            setMacroActualsAndUpdateMealMacroActuals(mealIngredient, state: &state)
        }

        // Keep applying adjustment passes until a full pass adds
        // nothing. Once a pass fails, no state has changed, so
        // re-running it cannot succeed — no retry loop needed.
        while tryAddingAdjustments(&state, using: &rng) { }

        // Commit: one @Published publish + one UserDefaults
        // serialize for the rows, one publish for the macros.
        mealIngredientMgr.mealIngredients = state.rows
        macrosMgr.macros = state.macros
    }


    private func tryAddingAdjustments<R: RandomNumberGenerator>(_ state: inout GenerationState, using rng: inout R) -> Bool {
        for adjustment in adjustmentOrder(using: &rng) {
            if tryAddingAdjustment(adjustment, state: &state) {
                return true
            }
        }
        return false
    }


    // This algorithm is best described by example using an ordered
    // list of adjustments annotated with adjustment groups:
    //
    // adj adj-group
    // a   g1
    // b
    // c   g2
    // d   g1
    // e   g2
    // f   g1
    // g
    //
    // Will produce the following order of adjustments where the items
    // inside the [] are returned in a randomized order that may change
    // on each invocation of the algorithm:
    //
    // [a d f]* b [c e]* g
    // * in some random order
    //
    // Thus the following are potential orders returned:
    // f a d b e c g
    // d f a b c e g
    // a d f b c e g
    func adjustmentOrder<R: RandomNumberGenerator>(using rng: inout R) -> [Adjustment] {
        var adjustmentOrder: [Adjustment] = []
        var adjustmentGroupSeen: [String] = []

        for adjustment in adjustmentMgr.getAll() {

            // If the adjustment is not part of a group add it in the
            // order it was found
            if adjustment.group == "" {
                adjustmentOrder.append(adjustment)
                continue
            }

            // When the first adjustment in an adjustment group is
            // found, all subsequent adjustments in the adjustment
            // group are processed, so ignore them if we see them a
            // second time.
            if adjustmentGroupSeen.contains(adjustment.group) {
                continue
            }

            // All adjustments in the same adjustment group are added
            // to the adjustment order sequentially beginning with the
            // position of the first adjustment in the group, but
            // their order is randomized.
            // Expand from getAll() (ACTIVE adjustments only) — the
            // raw `adjustments` array includes deactivated rules,
            // which must not sneak back in via their group.
            adjustmentGroupSeen.append(adjustment.group)
            adjustmentOrder.append(contentsOf:
                adjustmentMgr.getAll()
                  .filter { $0.group == adjustment.group }
                  .shuffled(using: &rng))
        }

        return adjustmentOrder
    }


    private func tryAddingAdjustment(_ adjustment: Adjustment, state: inout GenerationState) -> Bool {

        let mealIngredient = state.rows.first(where: { $0.name == adjustment.name })


        // Skip Manual / Done — both are explicit user signals to
        // leave the row alone (user controls the amount; auto stays
        // out).
        if let mi = mealIngredient,
           mi.adjustment == Constants.Manual
           || mi.adjustment == Constants.Done {
            return false
        }


        // If the adjustment has constraints, and the new meal
        // ingredient amount with the adjustment applied would exceed
        // the adjustment's maximum constraint for the meal ingredient
        // then the adjustment cannot be applied. The same cap applies
        // when the adjustment would CREATE the row (starting amount
        // 0): an adjustment whose own amount exceeds its maximum
        // must not sneak a too-big row into the meal.
        if adjustment.constraints {
            if ((mealIngredient?.amount ?? 0) + adjustment.amount) > adjustment.maximum {
                return false
            }
        }


        // If the result of applying the adjustment would result in
        // the fat, netCarbs, or protein macros exceeding the daily
        // macro limits then the adjustment cannot be applied.
        //
        // Resolve group/base names to the selected variant. The auto-
        // adjust engine targets Foods by name (not specific rows), so
        // use the row's member if a row already exists, else the
        // Food's global default. If the target ingredient no longer
        // resolves (e.g. an adjustment left over for a removed base
        // entry), the adjustment simply can't be applied — skip it
        // instead of force-unwrapping into a crash.
        let resolvedName = mealIngredient.map { resolver.currentName($0) }
            ?? resolver.currentName(forFoodName: adjustment.name)
        guard let ingredient = ingredientMgr.getByName(name: resolvedName) else {
            return false
        }
        let servings = ingredient.servingSize > 0
            ? (adjustment.amount * foodMgr.consumptionGrams(for: ingredient)) / ingredient.servingSize
            : 0

        let fat: Double = Double(ingredient.fat * servings)
        let netCarbs: Double = Double(ingredient.netCarbs * servings)
        let protein: Double = Double(ingredient.protein * servings)

        if state.macros.fatGoal < state.macros.fat + fat ||
             state.macros.netCarbsMaximum < state.macros.netCarbs + netCarbs ||
             state.macros.proteinGoal < state.macros.protein + protein {
            return false
        }


        // At this point, the adjustment "fits" and can be applied.
        // Account for just the DELTA against the running macro totals
        // (and onto the target row's running macros) BEFORE mutating
        // the row's amount — mirrors the original incremental
        // bookkeeping. automaticAdjustment then bumps the row amount
        // (creating the row if it didn't exist).
        if let mi = mealIngredient {
            setMacroActualsAndUpdateMealMacroActuals(mi, amountOverride: Double(adjustment.amount), state: &state)
        }
        automaticAdjustment(name: adjustment.name, amount: adjustment.amount, state: &state)
        // Row was just created by automaticAdjustment (no prior row) —
        // account its delta now that it exists.
        if mealIngredient == nil,
           let created = state.rows.first(where: { $0.name == adjustment.name }) {
            setMacroActualsAndUpdateMealMacroActuals(created, amountOverride: Double(adjustment.amount), state: &state)
        }
        return true
    }


    // For a given meal ingredient (specified by name), use the total
    // calories consumed to determine the servings consumed, and then
    // use the servings consumed to calculate the calories and macros
    // for the meal ingredient, and then set those macro values on the
    // meal ingredient.
    //
    // Next, add the meal ingredient's macros to the cumulative
    // meal's macros.
    // `amountOverride` lets the auto-adjust engine account for just
    // the DELTA it is applying (adjustment.amount) instead of the
    // row's full amount — preserving the original incremental macro
    // bookkeeping. The bulk pass in generateMeal() passes nil so the
    // row's full amount is used. Resolution (which member ingredient)
    // is row-aware in both cases.
    private func setMacroActualsAndUpdateMealMacroActuals(_ mi: MealIngredient,
                                                          amountOverride: Double? = nil,
                                                          state: inout GenerationState) {

        // Category placeholder — not a real food, contributes ZERO
        // calories/macros and never resolves to an ingredient.
        // Mirrors the composite branch's early structure but emits
        // nothing. Must be checked BEFORE any resolution attempt so
        // a placeholder can never crash or skew totals.
        if mi.isFoodTypeSlot { return }

        let amount = amountOverride ?? Double(mi.amount)

        // Composite row: macros are the sum of each component's
        // selected variant at the component's amount.
        if mi.isComposite {
            var c = 0.0, f = 0.0, fi = 0.0, nc = 0.0, p = 0.0
            for part in mi.compositeParts {
                guard let ing = ingredientMgr.getByName(name: part.selectedVariantName),
                      ing.servingSize > 0 else { continue }
                let servings = (part.amount * foodMgr.consumptionGrams(for: ing)) / ing.servingSize
                c  += ing.calories * servings
                f  += ing.fat      * servings
                fi += ing.fiber    * servings
                nc += ing.netCarbs * servings
                p  += ing.protein  * servings
            }
            setMacroActuals(id: mi.id, calories: c, fat: f, fiber: fi, netcarbs: nc, protein: p, state: &state)
            state.macros = state.macros.addMacroActuals(calories: c, fat: f, fiber: fi, netCarbs: nc, protein: p)
            return
        }

        // Determine the number of servings consumed by taking the
        // total grams consumed divided by the grams per serving.
        // For a GROUP row the meal ingredient is stored under the
        // group name; nutrition must come from THIS row's selected
        // member (currentName(mi) is row-aware).
        guard let ingredient = ingredientMgr.getByName(name: resolver.currentName(mi)) else {
            // Group member deleted / unresolved — contribute nothing
            // rather than crashing on a force-unwrap.
            return
        }
        let servings = ingredient.servingSize > 0
            ? (amount * foodMgr.consumptionGrams(for: ingredient)) / ingredient.servingSize
            : 0

        // Determine the calories and macros by multiplying the
        // calories/macros per serving times the number of servings
        // consumed.
        let calories: Double = Double(ingredient.calories * servings)
        let fat: Double = Double(ingredient.fat * servings)
        let fiber: Double = Double(ingredient.fiber * servings)
        let netcarbs: Double = Double(ingredient.netCarbs * servings)
        let protein: Double = Double(ingredient.protein * servings)

        // Update the macro values on this specific meal row (id-keyed
        // so duplicated rows of the same Food each get their own),
        // then add them to the overall meal actuals.
        setMacroActuals(id: mi.id, calories: calories, fat: fat, fiber: fiber, netcarbs: netcarbs, protein: protein, state: &state)
        state.macros = state.macros.addMacroActuals(calories: calories, fat: fat, fiber: fiber, netCarbs: netcarbs, protein: protein)
    }


    // ------------------------------------------------------------
    // Local-copy equivalents of the MealIngredientMgr mutations the
    // engine used to call. Same row-level semantics (the MealIngredient
    // copy-and-mutate methods are shared); they just target the
    // working array instead of the published one.
    // ------------------------------------------------------------

    private func undoAutoAdjustments(_ state: inout GenerationState) {

        // Go through each meal ingredient that was auto adjusted
        for mealIngredient in state.rows.filter({ $0.adjustment == Constants.Automatic }) {

            // A row the engine itself created (priorState Ingredient)
            // is deleted to reverse the adjustment; a pre-existing row
            // gets its amount restored to originalAmount.
            if mealIngredient.priorState == Constants.Ingredient {
                state.rows.removeAll { $0.id == mealIngredient.id }
                continue
            }

            if let index = state.rows.firstIndex(where: { $0.id == mealIngredient.id }) {
                state.rows[index] = state.rows[index].undoAdjustment()
            }
        }
    }


    private func automaticAdjustment(name: String, amount: Double, state: inout GenerationState) {
        if let index = state.rows.firstIndex(where: { $0.name == name }) {
            state.rows[index] = state.rows[index].automaticAdjustment(amount: amount)
            return
        }

        // Created by the adjustment engine, so mark it Automatic with
        // a priorState of Ingredient: undoAutoAdjustments only visits
        // Automatic rows and deletes those whose priorState is
        // Ingredient, which reverses this creation.
        state.rows.append(MealIngredient(name: name,
                                         amount: amount,
                                         adjustment: Constants.Automatic,
                                         priorState: Constants.Ingredient))
    }


    private func setMacroActuals(id: String, calories: Double, fat: Double, fiber: Double, netcarbs: Double, protein: Double, state: inout GenerationState) {
        if let index = state.rows.firstIndex(where: { $0.id == id }) {
            state.rows[index] = state.rows[index].setMacroActuals(calories: calories, fat: fat, fiber: fiber, netcarbs: netcarbs, protein: protein)
        }
    }
}
