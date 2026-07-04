import Foundation


// An ingredient group / variant set. The group (e.g. "Eggs") is
// what gets added to a meal; its members are individual brand
// ingredients whose `Ingredient.foodName` equals this group's
// `name`. One member is the default — used when the group is first
// added to a meal and as the fallback if a selected member is
// later deleted.
//
// Named `Food` (not `Group`) to avoid colliding with
// SwiftUI.Group, which the view layer uses as a container.
struct Food: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    // The Food's category. This is the single source of truth for
    // type: member ingredients inherit it via their foodName, they
    // no longer carry their own type.
    var type: IngredientType
    // Portion config now lives primarily on the Food so one value
    // applies to every variant. Member ingredients keep their own
    // `defaultAmount` / `stepAmount` only as an OPTIONAL OVERRIDE
    // that wins when non-zero (multi-size foods like Avocado). 0 =
    // inherit / no Food-level value.
    var defaultAmount: Double
    var stepAmount: Double
    // The consumption unit (tablespoon / egg / can / gram …) and the
    // grams that one such unit weighs. Unlike defaultAmount these are
    // ALWAYS authoritative on the Food: every member ingredient of
    // the Food is prepped/consumed in the same unit, so there is no
    // "0 = none" sentinel. Member ingredients still carry their own
    // stored consumptionUnit/consumptionGrams (raw value edited on
    // the ingredient form), but meal math reads the Food's value via
    // FoodMgr.consumptionUnit(for:) / .consumptionGrams(for:).
    var consumptionUnit: Unit
    var consumptionGrams: Double
    var currentIngredientName: String

    init(id: String = UUID().uuidString,
         name: String,
         type: IngredientType,
         defaultAmount: Double = 0,
         stepAmount: Double = 0,
         consumptionUnit: Unit = .gram,
         consumptionGrams: Double = 1,
         currentIngredientName: String) {
        self.id = id
        self.name = name
        self.type = type
        self.defaultAmount = defaultAmount
        self.stepAmount = stepAmount
        self.consumptionUnit = consumptionUnit
        self.consumptionGrams = consumptionGrams
        self.currentIngredientName = currentIngredientName
    }
}


class FoodMgr: ObservableObject {

    // Config-owned, exactly like IngredientMgr — the config is the
    // source of truth and is rebuilt every launch. Each entry is a
    // food and its current (default) member ingredient. Runtime
    // changes (ensure / setCurrent) are session-scoped; there is no
    // UserDefaults persistence.
    @Published var foods: [Food] = []


    init() {
        self.foods = ConfigStore.shared.runtimeFoods()
    }


    // Category resolution helpers — type lives only on Food now, so
    // every "is this ingredient a meat / supplement / what type"
    // question routes through here.
    func type(of ingredient: Ingredient) -> IngredientType? {
        getByName(name: ingredient.foodName)?.type
    }

    func isMeat(_ i: Ingredient) -> Bool {
        type(of: i) == .meat
    }

    func isSupplement(_ i: Ingredient) -> Bool {
        type(of: i) == .supplement
    }


    // Seed (append) position of a Food in `foods`. Since `foods`
    // preserves init() append order at runtime, this is the
    // authoritative within-category display order. Unknown name =>
    // Int.max so it sorts last (mirrors the type(of:) helper shape).
    func seedOrder(ofFoodNamed name: String) -> Int {
        foods.firstIndex { $0.name == name } ?? Int.max
    }

    func seedOrder(of ingredient: Ingredient) -> Int {
        seedOrder(ofFoodNamed: ingredient.foodName)
    }


    // Portion-config resolution. The Food owns the primary value;
    // an ingredient's own value is an override that wins when != 0.

    // Effective seed amount for a new meal row. Resolution order:
    //   1. profile per-Food override (profile.defaults[foodName]) — the
    //      ACTIVE profile gets its own meal default per Food. Caller
    //      passes profileMgr.profile so meal-add code can be profile-
    //      aware without coupling Food to ProfileMgr.
    //   2. ingredient.defaultAmount (variant-level override, != 0)
    //   3. Food.defaultAmount (group-level baseline, 0 = no preset)
    func effectiveDefaultAmount(for i: Ingredient, profile: Profile? = nil) -> Double {
        if let p = profile?.defaults[i.foodName], p > 0 { return p }
        return i.defaultAmount != 0
            ? i.defaultAmount
            : (getByName(name: i.foodName)?.defaultAmount ?? 0)
    }

    // Raw Food-level step for this ingredient's Food (0 if none).
    // The ingredient-wins + auto-heuristic combination is applied at
    // the step call site (AmountStepper.effectiveStep).
    func foodStepAmount(for i: Ingredient) -> Double {
        getByName(name: i.foodName)?.stepAmount ?? 0
    }


    // Consumption-unit resolution. Unlike defaultAmount the Food is
    // the authoritative source — every member of a Food is consumed
    // in the same unit, so there is no ingredient-level override that
    // "wins". The ingredient's own stored value is used only as a
    // defensive fallback if the Food can't be found (e.g. an
    // ungrouped ingredient with empty foodName), mirroring the shape
    // of effectiveDefaultAmount(for:).
    func consumptionUnit(for i: Ingredient) -> Unit {
        getByName(name: i.foodName)?.consumptionUnit ?? i.consumptionUnit
    }


    // `name` is a Food name (meal rows / adjustments target a Food).
    // Resolve via the Food's current member; never force-unwraps (the
    // bare canonical ingredients are gone). Shared by AdjustmentAdd
    // and AdjustmentEdit, which previously copy-pasted this.
    func consumptionUnit(for name: String, ingredientMgr: IngredientMgr) -> Unit {
        if let f = getByName(name: name),
           let ing = ingredientMgr.getByName(name: f.currentIngredientName) {
            return consumptionUnit(for: ing)
        }
        if let ing = ingredientMgr.getByName(name: name) {
            return consumptionUnit(for: ing)
        }
        return .gram
    }

    func consumptionGrams(for i: Ingredient) -> Double {
        getByName(name: i.foodName)?.consumptionGrams ?? i.consumptionGrams
    }


    // Foods sorted by category (IngredientType.sortRank) then seed
    // (append) order — the order foods.append(...) appears in
    // init(). Name is only the final stable fallback.
    var foodsSorted: [Food] {
        foods.enumerated().sorted { lhs, rhs in
            let a = lhs.element, b = rhs.element
            if a.type.sortRank != b.type.sortRank {
                return a.type.sortRank < b.type.sortRank
            }
            if lhs.offset != rhs.offset {
                return lhs.offset < rhs.offset
            }
            return a.name < b.name
        }.map { $0.element }
    }

    // Food names in category (sortRank) then name order — the order
    // user-facing Food pickers should present.
    var namesSorted: [String] {
        foodsSorted.map { $0.name }
    }


    func getByName(name: String) -> Food? {
        foods.first { $0.name == name }
    }


    var names: [String] {
        foods.map { $0.name }.sorted()
    }


    // Create the food if it doesn't exist yet (first member added
    // becomes the default). Idempotent — returns the existing food
    // untouched if the name is already known.
    @discardableResult
    func ensure(name: String, defaultMember: String, type: IngredientType) -> Food {
        if let existing = getByName(name: name) { return existing }
        let f = Food(name: name, type: type, currentIngredientName: defaultMember)
        foods.append(f)
        return f
    }


    func setCurrent(food name: String, member: String) {
        guard let idx = foods.firstIndex(where: { $0.name == name }) else { return }
        foods[idx].currentIngredientName = member
    }


    // Drop a food entirely (e.g. its last member was unassigned).
    func remove(name: String) {
        foods.removeAll { $0.name == name }
    }
}


// ============================================================
// FoodComposite — a named recipe of Food components (PB&J =
// Bread + Peanut Butter + Jelly). A component references a Food
// by name; at meal time it resolves to that Food's currently
// selected variant. `amount` is in that variant's consumption
// unit. Swapping a component's brand/size is just changing the
// referenced Food's selected variant.
// ============================================================
struct CompositeComponent: Codable, Equatable, Identifiable {
    var id: String { foodName }
    var foodName: String
    var amount: Double
}

struct FoodComposite: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var components: [CompositeComponent]

    init(id: String = UUID().uuidString,
         name: String,
         components: [CompositeComponent]) {
        self.id = id
        self.name = name
        self.components = components
    }
}


class FoodCompositeMgr: ObservableObject {

    @Published var composites: [FoodComposite] = [] {
        didSet { serialize() }
    }

    private(set) var profileId: String

    // Per-profile pattern: composites are stored under a per-profile
    // UserDefaults key ("foodComposite.<profileId>") so switching the
    // active profile swaps the composite library. On first load for a
    // given profile, we attempt a one-shot migration from the legacy
    // unkeyed "foodComposite" store (gated by a per-profile flag), then
    // seed defaults if still empty. Use reload(forProfileId:) to swap
    // the active profile at runtime.
    init(profileId: String) {
        self.profileId = profileId
        deserialize()
        if composites.isEmpty { seed() }
    }

    func reload(forProfileId newId: String) {
        self.profileId = newId
        deserialize()
        if composites.isEmpty { seed() }
    }

    func getByName(name: String) -> FoodComposite? {
        composites.first { $0.name == name }
    }

    var names: [String] { composites.map { $0.name }.sorted() }

    @discardableResult
    func create(name: String, components: [CompositeComponent]) -> FoodComposite {
        if let existing = getByName(name: name) { return existing }
        let c = FoodComposite(name: name, components: components)
        composites.append(c)
        return c
    }

    func update(_ composite: FoodComposite) {
        if let i = composites.firstIndex(where: { $0.id == composite.id }) {
            composites[i] = composite
        }
    }

    func remove(name: String) {
        composites.removeAll { $0.name == name }
    }

    // Default composites — the swappable replacements for the
    // retired flat PBJ*/SJ*/…W seed ingredients.
    private func seed() {
        composites = [
            FoodComposite(name: "PB&J", components: [
                CompositeComponent(foodName: "Bread", amount: 2),
                CompositeComponent(foodName: "Peanut Butter", amount: 2),
                CompositeComponent(foodName: "Jelly", amount: 1),
            ]),
            FoodComposite(name: "SunButter & Jelly", components: [
                CompositeComponent(foodName: "Bread", amount: 2),
                CompositeComponent(foodName: "Sunflower Butter", amount: 2),
                CompositeComponent(foodName: "Jelly", amount: 1),
            ]),
            FoodComposite(name: "Wrap", components: [
                CompositeComponent(foodName: "Bread", amount: 1),
                CompositeComponent(foodName: "Turkey", amount: 3),
                CompositeComponent(foodName: "Cheese", amount: 1),
                CompositeComponent(foodName: "String Cheese", amount: 1),
            ]),
        ]
    }

    private var storageKey: String { "foodComposite.\(profileId)" }

    // Persistence codec. Built per use because storageKey re-points
    // when the profile switches. On decode failure the store backs up
    // the blob under "<key>.corrupt" and loudly logs before we reseed.
    private var store: UserDefaultsStore<[FoodComposite]> {
        UserDefaultsStore(key: storageKey)
    }

    func serialize() {
        store.save(composites)
    }

    func deserialize() {
        if let saved = store.load() {
            self.composites = saved
            return
        }
        // One-shot migration from the legacy unkeyed "foodComposite"
        // store. Only the FIRST profile to load post-refactor consumes
        // it (gated by the global "foodComposite.legacyConsumed" flag);
        // later profiles fall through to seed() defaults via the
        // caller's "if composites.isEmpty { seed() }" path.
        let migratedFlagKey = "foodComposite.migrated.\(profileId)"
        let legacyConsumedKey = "foodComposite.legacyConsumed"
        if !UserDefaults.standard.bool(forKey: migratedFlagKey) {
            UserDefaults.standard.set(true, forKey: migratedFlagKey)
            if !UserDefaults.standard.bool(forKey: legacyConsumedKey),
               let legacy = UserDefaultsStore<[FoodComposite]>(key: "foodComposite").load() {
                self.composites = legacy
                UserDefaults.standard.set(true, forKey: legacyConsumedKey)
                store.save(legacy)
                return
            }
        }
        self.composites = []
    }
}
