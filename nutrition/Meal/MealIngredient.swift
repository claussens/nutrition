import Foundation


enum Constants {
    // Three user-visible adjustment modes (plus Default as a
    // transient internal state):
    //   Default   — fresh row, hasn't been touched; renders black.
    //               Auto-adjustments can promote it to Automatic.
    //   Manual    — user controls amount; auto-adjust skips this
    //               row; renders black. Same color as Default; user
    //               doesn't see a difference.
    //   Automatic — system auto-adjusted this generation cycle;
    //               renders green.
    //   Done      — user-locked / "complete"; renders blue.
    //               Inc/dec/pill are disabled; auto-adjust skips.
    static let Default: Int = 1
    static let Manual: Int = 2
    static let Automatic: Int = 3
    static let Done: Int = 5

    static let Ingredient: Int = 2
    static let Inactive: Int = 3
    static let Active: Int = 4
}


class MealIngredientMgr: ObservableObject {


    // Per-profile id; meal data is namespaced under this id so
    // switching profile swaps meal data. Mutable so `reload` can
    // repoint the manager when the active profile changes.
    private(set) var profileId: String

    // The active profile's display name. Carried alongside profileId
    // so resetMealIngredients() can seed defaults from config keyed by
    // this profile's slug (profileName.lowercased()). profileId is a
    // UUID — not human-stable across fresh installs — so the config
    // lookup keys on the slug derived from the name instead.
    private(set) var profileName: String

    // The profile's config slug: meals/supplements in ConfigStore are
    // keyed by the lowercased profile name (e.g. "shane", "caden").
    private var profileSlug: String { profileName.lowercased() }

    // Per-profile storage key. Reads and writes go through this so
    // every profile keeps its own EDITED meal data under
    // "mealIngredient.<id>", so user edits persist between launches.
    private var storageKey: String { "mealIngredient.\(profileId)" }

    // Persistence codec. Built per use because storageKey re-points
    // when the profile switches. On decode failure the store backs up
    // the blob under "<key>.corrupt" and loudly logs before we reseed.
    private var store: UserDefaultsStore<[MealIngredient]> {
        UserDefaultsStore(key: storageKey)
    }


    @Published var mealIngredients: [MealIngredient] = [] {
        didSet {
            serialize()
        }
    }


    // Per-profile init: set profileId/Name FIRST so storageKey and
    // profileSlug resolve, then load the user's saved (edited) meal
    // data; if none exists yet (fresh profile), seed it from config.
    init(profileId: String, profileName: String) {
        self.profileId = profileId
        self.profileName = profileName
        loadOrSeed()
    }


    // Repoint this manager at a different profile. Same load-or-seed
    // logic: load the target profile's saved meals, or seed from
    // config if that profile has none yet.
    func reload(forProfileId newId: String, profileName newName: String) {
        self.profileId = newId
        self.profileName = newName
        loadOrSeed()
    }


    // Shared init/reload body. If the profile has saved (user-edited)
    // meal data, load it so edits persist between launches. Otherwise
    // (first run / fresh profile — or a corrupt blob, which the store
    // has backed up and logged) seed the meals from ConfigStore.
    private func loadOrSeed() {
        self.mealIngredients = store.load() ?? []
        if mealIngredients.isEmpty { resetMealIngredients() }
    }


    func serialize() {
        store.save(mealIngredients)
    }


    // Seed this profile's meal from ConfigStore, keyed by the
    // profile's slug (profileName.lowercased()). Each ConfigMealRow is
    // mapped to a MealIngredient by which fields it carries:
    //   • category placeholder (row.category != nil) — a "pick a X"
    //     slot: name = the category label, foodType = the type raw
    //     value. Contributes ZERO macros, never resolves to an
    //     ingredient, and is replaced by a real Food row when the user
    //     picks one.
    //   • composite (row.composite != nil) — name = the composite
    //     food, with its resolved parts.
    //   • group (row.member != nil) — name = the group food, with the
    //     currently selected member.
    //   • ordinary — name = the food, at its amount.
    // Supplements (hidden from the meal list by default, but counted
    // toward daily V&M and macros) are appended after the meals.
    func resetMealIngredients() {
        var rows: [MealIngredient] = []

        for row in ConfigStore.shared.mealRows(forSlug: profileSlug) {
            if let category = row.category {
                rows.append(MealIngredient(name: category,
                                           amount: 0,
                                           foodType: row.foodType ?? ""))
            } else if let composite = row.composite {
                rows.append(MealIngredient(name: row.food ?? "",
                                           amount: row.amount ?? 0,
                                           compositeParts: composite.map {
                                               MealCompositePart(foodName: $0.food,
                                                                 selectedVariantName: $0.variant,
                                                                 amount: $0.amount)
                                           }))
            } else if let member = row.member {
                rows.append(MealIngredient(name: row.food ?? "",
                                           amount: row.amount ?? 0,
                                           selectedMemberName: member))
            } else {
                rows.append(MealIngredient(name: row.food ?? "",
                                           amount: row.amount ?? 0))
            }
        }

        for supp in ConfigStore.shared.supplements(forSlug: profileSlug) {
            rows.append(MealIngredient(name: supp.name,
                                       amount: supp.amount,
                                       isSupplement: true))
        }

        mealIngredients = rows
    }


    // Create a new meal ingredient and add it to the meal ingredients list.
    // Consumer is the Meal Add dialog.
    func create(name: String,
                amount: Double,
                adjustment: Int = Constants.Default,
                priorState: Int = Constants.Active,
                isSupplement: Bool = false,
                selectedMemberName: String = "",
                compositeParts: [MealCompositePart] = []) {

        let mealIngredient = MealIngredient(name: name,
                                            amount: amount,
                                            adjustment: adjustment,
                                            priorState: priorState,
                                            isSupplement: isSupplement,
                                            selectedMemberName: selectedMemberName,
                                            compositeParts: compositeParts)

        mealIngredients.append(mealIngredient)
    }


    // Duplicate an existing meal row into a new, independent row.
    // The clone keeps the source row's member selection, amount,
    // composite parts, supplement flag, and active state but gets a
    // FRESH id (and resets adjustment/priorState to Default so the
    // copy starts clean — the user can re-lock it independently).
    // The new row is inserted directly after its source so it shows
    // adjacent to the original in the list.
    func replicate(id: String) {
        guard let index = mealIngredients.firstIndex(where: { $0.id == id }) else {
            return
        }
        let src = mealIngredients[index]
        let clone = MealIngredient(name: src.name,
                                   originalAmount: src.amount,
                                   amount: src.amount,
                                   isSupplement: src.isSupplement,
                                   selectedMemberName: src.selectedMemberName,
                                   compositeParts: src.compositeParts)
        mealIngredients.insert(clone, at: index + 1)
    }


    // Change which member of a group this meal row uses. Macros are
    // recomputed by the next generateMeal() (resolution happens
    // there via the row's selectedMemberName). Keyed by the row's
    // unique id so multiple rows of the same Food are independent.
    func setSelectedMember(id: String, member: String) {
        if let index = mealIngredients.firstIndex(where: { $0.id == id }) {
            mealIngredients[index].selectedMemberName = member
        }
    }


    // Set a meal row's amount directly (used when switching Food
    // variants so the row adopts the new variant's defaultAmount).
    func setAmount(id: String, amount: Double) {
        if let index = mealIngredients.firstIndex(where: { $0.id == id }) {
            mealIngredients[index].amount = amount
        }
    }


    // Replace a composite row's resolved parts (variant swap /
    // amount change from the composite editor).
    func setCompositeParts(id: String, parts: [MealCompositePart]) {
        if let index = mealIngredients.firstIndex(where: { $0.id == id }) {
            mealIngredients[index].compositeParts = parts
        }
    }


    func manualAdjustment(id: String, name: String, amount: Double) {
        if let index = mealIngredients.firstIndex(where: { $0.id == id }) {
            mealIngredients[index] = mealIngredients[index].manualAdjustment(amount: amount)
            return
        }

        create(name: name, amount: amount, adjustment: Constants.Manual, priorState: Constants.Ingredient)
    }


    func undoManualAdjustment(id: String) {
        if let index = mealIngredients.firstIndex(where: { $0.id == id }) {
            if mealIngredients[index].adjustment == Constants.Manual {
                if mealIngredients[index].priorState == Constants.Ingredient {
                    delete(mealIngredients[index])
                    return
                }

                mealIngredients[index] = mealIngredients[index].undoAdjustment()
            }
        }
    }


    // Promote a row to Done (blue / fully locked). Called when the
    // user taps the name of a Manual or Default row. Keeps the
    // current amount. Keyed by row id so duplicated rows of the same
    // Food lock independently.
    func doneAdjustment(id: String, amount: Double) {
        if let index = mealIngredients.firstIndex(where: { $0.id == id }) {
            mealIngredients[index] = mealIngredients[index].doneAdjustment(amount: amount)
        }
    }


    // Revert a Done row to Default.
    //
    // resetAmount=true: caller has decided this ingredient is auto-
    //   eligible and the amount should be reset to originalAmount so
    //   the next generateMeal can let auto recompute cleanly.
    // resetAmount=false: caller has decided this is a manual-only
    //   ingredient; preserve the user's amount.
    func undoDoneAdjustment(id: String, resetAmount: Bool) {
        if let index = mealIngredients.firstIndex(where: { $0.id == id }) {
            if mealIngredients[index].adjustment == Constants.Done {
                mealIngredients[index] = mealIngredients[index].undoDoneAdjustment(resetAmount: resetAmount)
            }
        }
    }


    // Handles 3 cases (2 by automaticAdjustment() and one by create()):
    // 1a. meal ingredient exists, not previously adjusted
    // 1b. meal ingredient exists, previously adjusted
    // 2.  meal ingredient does not exist
    func automaticAdjustment(name: String, amount: Double) {

        if let index = mealIngredients.firstIndex(where: { $0.name == name }) {
            mealIngredients[index] = mealIngredients[index].automaticAdjustment(amount: amount)
            return
        }

        // Created by the adjustment engine, so mark it Automatic with a
        // priorState of Ingredient: undoAutoAdjustments() only visits
        // Automatic rows and deletes those whose priorState is Ingredient,
        // which reverses this creation.
        create(name: name, amount: amount, adjustment: Constants.Automatic, priorState: Constants.Ingredient)
    }


    func undoAutoAdjustments() {

        // Go through each meal ingredient that was auto adjusted
        for mealIngredient in mealIngredients.filter({ $0.adjustment == Constants.Automatic }) {

            // A meal ingredient may be in the meal adjustments list
            // that was not initially a meal ingredient and it needed
            // to be applied via the auto adjustment algorithm.  In
            // that case the meal ingredient would have been created
            // from the ingredient and activated.  In that case,
            // delete the meal ingredient to reverse the adjustment.
            if mealIngredient.priorState == Constants.Ingredient {
                delete(mealIngredient)
                continue
            }

            // SWIFT NUANCE: In order to update an object, we must
            // create a copy of the original object, update the copy,
            // and then replace the original object in the array with
            // the new object.
            if let index = mealIngredients.firstIndex(where: { $0.id == mealIngredient.id }) {
                mealIngredients[index] = mealIngredients[index].undoAdjustment()
            }
        }
    }


    // Get the meal ingredient by name
    func getByName(name: String) -> MealIngredient? {
        if let index = mealIngredients.firstIndex(where: { $0.name == name }) {
            return mealIngredients[index]
        }

        return nil
    }


    // Return every present meal ingredient. A meal is exactly the
    // rows that are present (the active/inactive concept was
    // removed). Supplements always render at the very bottom; within
    // each group the original insertion order is preserved since
    // filter is stable.
    func getAllMealIngredients() -> [MealIngredient] {
        return mealIngredients.filter { !$0.isSupplement }
             + mealIngredients.filter { $0.isSupplement }
    }


    // Return all the meal ingredient names
    func getNames() -> [String] {
        return mealIngredients.map { $0.name }
    }


    func update(_ mealIngredient: MealIngredient) {
        if let index = mealIngredients.firstIndex(where: { $0.id == mealIngredient.id }) {
            mealIngredients[index] = mealIngredient.update(mealIngredient: mealIngredient)
        }
    }


    // Flip the supplement flag on a meal ingredient.  When the flag
    // is on, the row is hidden from the Meal list unless the user
    // enables 'Show supplements' in the view-options menu.  V&M and
    // macros aggregations still include it.
    func toggleSupplement(_ mealIngredient: MealIngredient) -> MealIngredient? {
        if let index = mealIngredients.firstIndex(where: { $0.id == mealIngredient.id }) {
            mealIngredients[index] = mealIngredient.toggleSupplement()
            return mealIngredients[index]
        }
        return nil
    }


    func setMacroActuals(id: String, calories: Double, fat: Double, fiber: Double, netcarbs: Double, protein: Double) {
        if let index = mealIngredients.firstIndex(where: { $0.id == id }) {
            mealIngredients[index] = mealIngredients[index].setMacroActuals(calories: calories, fat: fat, fiber: fiber, netcarbs: netcarbs, protein: protein)
        }
    }


    func setMacroActualsToZero() {
        for index in stride(from: 0, through: mealIngredients.count - 1, by: 1) {
            mealIngredients[index] = mealIngredients[index].setMacroActualsToZero()
        }
    }


    func move(from: IndexSet, to: Int) {
        mealIngredients.move(fromOffsets: from, toOffset: to)
    }


    func deleteSet(indexSet: IndexSet) {
        mealIngredients.remove(atOffsets: indexSet)
    }


    func delete(_ mealIngredient: MealIngredient) {
        if let index = mealIngredients.firstIndex(where: { $0.id == mealIngredient.id }) {
            mealIngredients.remove(at: index)
        }
    }


    //    func resetAmountAll() {
    //        for mealIngredient in mealIngredients {
    //            if let index = mealIngredients.firstIndex(where: { $0.name == mealIngredient.name }) {
    //                mealIngredients[index] = mealIngredients[index].resetAmountToDefaultAmount()
    //            }
    //        }
    //    }
}


// One resolved component of a composite meal row: which Food, the
// variant currently chosen for it, and how much. Macros/cost come
// from the variant Ingredient at `amount` in its consumption unit.
struct MealCompositePart: Codable, Equatable, Identifiable {
    var id: String { foodName }
    var foodName: String
    var selectedVariantName: String
    var amount: Double
}


struct MealIngredient: Codable, Identifiable {
    var id: String

    var name: String

    var originalAmount: Double
    var amount: Double

    var calories: Double
    var fat: Double
    var fiber: Double
    var netcarbs: Double
    var protein: Double

    var adjustment: Int
    var priorState: Int

    // Supplements are meal ingredients that count toward daily macro
    // and V&M totals but are hidden from the Meal list by default
    // (toggle in the view-options menu to show them).
    var isSupplement: Bool

    // Non-empty ⇒ this meal row represents an ingredient GROUP
    // (`name` holds the group name) and this is the currently
    // selected member ingredient. Macros/cost resolve from the
    // member, not the group name. Empty ⇒ ordinary ingredient row.
    var selectedMemberName: String

    // Non-empty ⇒ this row is a FoodComposite; `name` holds the
    // composite name and macros/cost are the sum of these parts.
    var compositeParts: [MealCompositePart]

    // Non-empty ⇒ this row is a CATEGORY PLACEHOLDER, not a real
    // food. `name` holds the capitalized category label (e.g.
    // "Meat") and `foodType` holds the IngredientType rawValue
    // (e.g. "meat"). It contributes ZERO macros, never resolves to
    // an Ingredient, sorts to the very end of the meal list, and is
    // replaced by a real Food row when the user picks one. Empty ⇒
    // ordinary / composite row.
    var foodType: String

    var isComposite: Bool { !compositeParts.isEmpty }

    var isFoodTypeSlot: Bool { !foodType.isEmpty }


    init(id: String = UUID().uuidString,
         name: String,
         originalAmount: Double = 0,
         amount: Double,
         calories: Double = 0,
         fat: Double = 0,
         fiber: Double = 0,
         netcarbs: Double = 0,
         protein: Double = 0,
         adjustment: Int = Constants.Default,
         priorState: Int = Constants.Active,
         isSupplement: Bool = false,
         selectedMemberName: String = "",
         compositeParts: [MealCompositePart] = [],
         foodType: String = "") {

        self.id = id

        self.name = name

        if originalAmount == 0 {
            self.originalAmount = amount
        } else {
            self.originalAmount = originalAmount
        }
        self.amount = amount

        self.calories = calories
        self.fat = fat
        self.fiber = fiber
        self.netcarbs = netcarbs
        self.protein = protein

        self.adjustment = adjustment
        self.priorState = priorState

        self.isSupplement = isSupplement
        self.selectedMemberName = selectedMemberName
        self.compositeParts = compositeParts
        self.foodType = foodType
    }


    // Custom Codable decoder for back-compat: old saved data won't
    // have `isSupplement` so default to false.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.originalAmount = try c.decode(Double.self, forKey: .originalAmount)
        self.amount = try c.decode(Double.self, forKey: .amount)
        // `meat` was removed from the model. Old saved JSON may still
        // carry a "meat" key; Codable simply ignores unlisted keys, so
        // there is nothing to decode here and old data still loads.
        self.calories = try c.decode(Double.self, forKey: .calories)
        self.fat = try c.decode(Double.self, forKey: .fat)
        self.fiber = try c.decode(Double.self, forKey: .fiber)
        self.netcarbs = try c.decode(Double.self, forKey: .netcarbs)
        self.protein = try c.decode(Double.self, forKey: .protein)
        self.adjustment = try c.decode(Int.self, forKey: .adjustment)
        self.priorState = try c.decode(Int.self, forKey: .priorState)
        // `active` was removed from the model (a meal is exactly the
        // rows that are present). Old saved JSON may still carry an
        // "active" key; Codable ignores unlisted keys, and the seed is
        // rebuilt each launch anyway, so old data still loads.
        self.isSupplement = try c.decodeIfPresent(Bool.self, forKey: .isSupplement) ?? false
        // Migration-safe: absent in data saved before groups existed.
        self.selectedMemberName = try c.decodeIfPresent(String.self, forKey: .selectedMemberName) ?? ""
        self.compositeParts = try c.decodeIfPresent([MealCompositePart].self, forKey: .compositeParts) ?? []
        // Migration-safe: absent in data saved before category
        // placeholders existed.
        self.foodType = try c.decodeIfPresent(String.self, forKey: .foodType) ?? ""
    }


    // All the methods below return a modified copy. They use
    // `var c = self` and mutate only what changes, so every field
    // (selectedMemberName and any added later) is preserved without
    // having to re-list it at each call site.

    func toggleSupplement() -> MealIngredient {
        var c = self
        c.isSupplement.toggle()
        return c
    }


    func setMacroActualsToZero() -> MealIngredient {
        var c = self
        c.calories = 0
        c.fat = 0
        c.fiber = 0
        c.netcarbs = 0
        c.protein = 0
        return c
    }


    func setMacroActuals(calories: Double, fat: Double, fiber: Double, netcarbs: Double, protein: Double) -> MealIngredient {
        var c = self
        c.calories += calories
        c.fat += fat
        c.fiber += fiber
        c.netcarbs += netcarbs
        c.protein += protein
        return c
    }


    func manualAdjustment(amount: Double) -> MealIngredient {
        var c = self
        c.amount = amount
        c.adjustment = Constants.Manual
        c.priorState = Constants.Active
        return c
    }


    // Promote this row to Done (blue / locked complete).
    func doneAdjustment(amount: Double) -> MealIngredient {
        var c = self
        c.amount = amount
        c.adjustment = Constants.Done
        return c
    }


    // Revert from Done back to Default.
    //
    // resetAmount=true: amount goes back to originalAmount so the
    //   next generateMeal's auto-adjustment can compute the right
    //   amount cleanly without double-counting against the user's
    //   Done amount.
    // resetAmount=false: preserve the user's amount (manual-only
    //   ingredient — no auto-rule to overwrite, the user's amount
    //   should survive Done → manual mode).
    //
    // Active is always preserved as-is — we do NOT derive it from
    // priorState the way `undoAdjustment()` does. That derivation
    // breaks across multi-step user cycles because priorState gets
    // reset to Default during the auto-adjust round-trip, and a
    // subsequent Done → Default would then evaluate Default==Active
    // as false and silently deactivate the row.
    func undoDoneAdjustment(resetAmount: Bool) -> MealIngredient {
        var c = self
        c.amount = resetAmount ? self.originalAmount : self.amount
        c.adjustment = Constants.Default
        return c
    }


    func automaticAdjustment(amount: Double) -> MealIngredient {

        if adjustment == Constants.Manual || adjustment == Constants.Done {
            return self
        }

        if adjustment == Constants.Default {
            var c = self
            c.amount = self.amount + amount
            c.adjustment = Constants.Automatic
            c.priorState = Constants.Active
            return c
        }

        var c = self
        c.amount = self.amount + amount
        return c
    }


    // Remove the adjustment to a meal ingredient.
    func undoAdjustment() -> MealIngredient {
        var c = self
        c.amount = self.originalAmount
        c.adjustment = Constants.Default
        c.priorState = Constants.Default
        return c
    }


    func update(mealIngredient: MealIngredient) -> MealIngredient {
        return mealIngredient
    }
}


// MARK: - Meal-row resolution (single source of truth)
//
// A meal row's `name` is a Food name. Exactly ONE algorithm decides
// which Ingredient a row resolves to; it is shared by the macro
// engine (MealList), the V&M totals, the cost breakdown, the daily
// summary snapshot, and the per-100g drilldowns. These previously
// each had their own lookup, and the divergence meant the macro
// gauges, the V&M page, and the meal cost could disagree about the
// same row. Resolution order:
//   1. the row's own selectedMemberName (per-row choice) if it
//      still names a real ingredient,
//   2. the ACTIVE PROFILE's preferred variant for this Food
//      (profile.foodMember[foodName]) if it names a real ingredient,
//   3. the Food's global currentIngredientName default,
//   4. the literal name (plain ungrouped ingredient row).
// Fallbacks keep it crash-proof if data is inconsistent.
struct MealResolver {
    let ingredientMgr: IngredientMgr
    let foodMgr: FoodMgr
    let foodMember: [String: String]   // active profile's per-Food variant prefs

    init(ingredientMgr: IngredientMgr, foodMgr: FoodMgr, profile: Profile) {
        self.ingredientMgr = ingredientMgr
        self.foodMgr = foodMgr
        self.foodMember = profile.foodMember
    }

    // Row-aware resolution (honors the row's selected member).
    func currentName(_ mi: MealIngredient) -> String {
        if !mi.selectedMemberName.isEmpty,
           ingredientMgr.getByName(name: mi.selectedMemberName) != nil {
            return mi.selectedMemberName
        }
        return currentName(forFoodName: mi.name)
    }

    // Name-only resolution (no per-row member). Used by the auto-
    // adjust engine, which targets Foods by name, not specific rows.
    func currentName(forFoodName foodOrName: String) -> String {
        if let preferred = foodMember[foodOrName],
           ingredientMgr.getByName(name: preferred) != nil {
            return preferred
        }
        if let f = foodMgr.getByName(name: foodOrName),
           ingredientMgr.getByName(name: f.currentIngredientName) != nil {
            return f.currentIngredientName
        }
        return foodOrName
    }

    // Category placeholders never resolve (zero macros, no cost, no
    // unit); composites have no single ingredient — callers sum
    // their parts instead.
    func resolvedIngredient(_ mi: MealIngredient) -> Ingredient? {
        if mi.isFoodTypeSlot { return nil }
        if let ing = ingredientMgr.getByName(name: currentName(mi)) {
            return ing
        }
        // Last-ditch: any surviving member of the Food.
        return ingredientMgr.getAll().first { $0.foodName == mi.name }
    }
}


// Total cost of a composite meal row: sum of each component's
// selected variant cost-per-gram × grams consumed. Components
// without pricing (totalGrams == 0) contribute 0.
func compositeCost(_ mi: MealIngredient, _ ingredientMgr: IngredientMgr, _ foodMgr: FoodMgr) -> Double {
    var total = 0.0
    for part in mi.compositeParts {
        guard let ing = ingredientMgr.getByName(name: part.selectedVariantName) else { continue }
        let grams = ing.effectiveTotalGrams
        guard grams > 0 else { continue }
        let costPerGram = ing.totalCost / grams
        total += costPerGram * (part.amount * foodMgr.consumptionGrams(for: ing))
    }
    return total
}
