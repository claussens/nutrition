import SwiftUI


// ============================================================
// Shared Add/Edit ingredient form sections. IngredientAdd and
// IngredientEdit previously pasted ~250 near-identical lines of
// product / macro / consumption / Food / V&M rows (with drifted
// labels — Add said "Company", Edit said "Brand"). Both screens
// now bind their draft Ingredient into this one view; `mode`
// gates the handful of rows that only make sense once the
// ingredient has been saved (cost/100g, per-profile defaults,
// the default-variant toggle).
// ============================================================

enum IngredientFormMode {
    case add
    case edit
}


struct IngredientFormSections: View {

    @EnvironmentObject var foodMgr: FoodMgr
    // Only read by the edit-mode per-profile rows.
    @EnvironmentObject var profileMgr: ProfileMgr

    @Binding var ingredient: Ingredient
    let mode: IngredientFormMode

    // Category for a brand-new Food created from this screen. An
    // existing Food's type is inherited and never edited here.
    // Owned by the parent screen because its save() needs it for
    // the deferred foodMgr.ensure.
    @Binding var newFoodType: IngredientType

    @State private var newGroupName = ""

    var body: some View {
        Group {
            productSection
            macroSection
            consumptionSection
            groupSection
            vitaminAndMineralsSection
        }
    }

    private var productSection: some View {
        Section(header: Text("Optional Product Details")) {
            NameValue("URL", $ingredient.url, edit: true)
            NameValue("Brand", $ingredient.brand, edit: true)
            NameValue("Product", $ingredient.fullName, edit: true)
            NameValue("Cost", $ingredient.totalCost, .dollar, precision: 2, edit: true)
            NameValue("Grams", description: "total ingredient grams in the product", $ingredient.totalGrams, edit: true)
            if mode == .edit {
                NameValue("Cost / 100g", description: "computed: cost ÷ grams × 100", $ingredient.costPer100, .dollar, precision: 2)
            }
        }
    }

    private var macroSection: some View {
        Section(header: Text("Macronutrients")) {
            NameValue("Serving Size", $ingredient.servingSize, edit: true)
            NameValue("Calories", $ingredient.calories, .calorie, edit: true)
            NameValue("Fat", $ingredient.fat, edit: true)
            NameValue("Fiber", $ingredient.fiber, edit: true)
            NameValue("Net Carbs", $ingredient.netCarbs, edit: true)
            NameValue("Protein", $ingredient.protein, edit: true)
        }
    }

    private var consumptionSection: some View {
        Section(header: Text("Preparation/Consumption Unit")) {
            NameValue("Consumption Unit", description: "preferred meal prep/consumption unit", $ingredient.consumptionUnit, options: Unit.ingredientOptions(), control: .picker)
            NameValue("Grams / Unit", description: "grams per each prep/consumption unit", $ingredient.consumptionGrams, edit: true)
            if mode == .edit {
                NameValue("Step amount", description: "0 = auto by unit & serving size", $ingredient.stepAmount, ingredient.consumptionUnit, edit: true)
                // Per-profile default. Keyed by Food name so every
                // variant of the same Food shows the active profile's
                // single shared value. 0 here = no override -> falls
                // back to ingredient.defaultAmount then Food default.
                NameValue("Default amount (\(profileMgr.profile.name))",
                          description: "seed amount when this Food is added to a meal; per active profile",
                          Binding(
                            get: { profileMgr.profile.defaults[ingredient.foodName] ?? 0 },
                            set: { profileMgr.setDefault(foodName: ingredient.foodName, amount: $0) }
                          ),
                          ingredient.consumptionUnit,
                          edit: true)
                // Per-profile preferred variant. When ON, this profile
                // resolves the "\(ingredient.foodName)" Food to THIS
                // variant in meal rows, eye-picker adds, and auto-
                // adjust — overriding the Food's global default
                // (Food.currentIngredientName). Per-row
                // selectedMemberName still wins over this.
                NameValue("Default variant for \(ingredient.foodName) (\(profileMgr.profile.name))",
                          description: "use this variant whenever this Food is added or auto-adjusted",
                          Binding<Bool>(
                            get: { profileMgr.profile.foodMember[ingredient.foodName] == ingredient.name },
                            set: { isOn in
                                profileMgr.setFoodMember(
                                    foodName: ingredient.foodName,
                                    ingredientName: isOn ? ingredient.name : nil)
                            }
                          ),
                          control: .toggle)
            }
        }
    }

    // Group / variant membership. Picking or creating a Food makes
    // this ingredient a member once saved; the Food is the thing
    // added to a meal and variants are swapped via long-press on the
    // meal row. The FoodMgr mutation (ensure) is deferred to each
    // screen's save() so a cancelled Add/Edit leaves FoodMgr
    // untouched — Create below only stages the name on the draft.
    // (Edit's Create used to call foodMgr.ensure immediately, which
    // leaked a Food when the edit was cancelled; both screens now
    // follow the draft-editing policy.)
    private var isGroupDefault: Bool {
        guard !ingredient.foodName.isEmpty else { return false }
        return foodMgr.getByName(name: ingredient.foodName)?.currentIngredientName == ingredient.name
    }

    private var groupSection: some View {
        Section(header: Text("Food"),
                footer: Text("Optional. Ingredients sharing a Food are collapsed to one meal row; long-press that row in the meal to pick which variant.")
                  .font(.caption2)) {

            Picker("Food", selection: $ingredient.foodName) {
                Text("None").tag("")
                ForEach(foodMgr.namesSorted, id: \.self) { g in
                    Text(g).tag(g)
                }
            }

            // Category only applies when creating a brand-new Food;
            // selecting an existing Food inherits its category.
            Picker("New Food Type", selection: $newFoodType) {
                ForEach(IngredientType.allCases) { t in
                    Text(t.label).tag(t)
                }
            }
              .pickerStyle(.menu)

            HStack {
                TextField("New Food\u{2026}", text: $newGroupName)
                  .autocorrectionDisabled()
                Button("Create") {
                    let trimmed = newGroupName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    ingredient.foodName = trimmed
                    newGroupName = ""
                }
                  .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
                  .foregroundColor(Color.theme.blueYellow)
            }

            // The "default variant" toggle is edit-only — it keys off
            // a saved ingredient name, which a brand-new ingredient
            // doesn't have until Save.
            if mode == .edit && !ingredient.foodName.isEmpty {
                Toggle("Default variant of this Food", isOn: Binding(
                    get: { isGroupDefault },
                    set: { on in
                        if on {
                            foodMgr.setCurrent(food: ingredient.foodName,
                                               member: ingredient.name)
                        }
                    }
                ))
            }
        }
    }

    // V&M fields are always visible (no gating toggle) — leave a
    // field blank to record nothing. Row set and order live in
    // NutrientCatalog.vmFormRows.
    private var vitaminAndMineralsSection: some View {
        VitaminMineralForm(rows: NutrientCatalog.vmFormRows.map { d in
            (d.label, Binding(
                get: { ingredient[keyPath: d.ingredient] },
                set: { ingredient[keyPath: d.ingredient] = $0 }
            ))
        })
    }
}


// ============================================================
// Apply LLM-parsed values to an Ingredient. Only touches fields
// the LLM actually filled in (non-nil), so any existing values
// are preserved when the label didn't show them. Shared by both
// screens' prefill. (IngredientAdd previously applied its own
// core-macro-only subset and dropped ingredientsList/allergens;
// both flows now apply the full parsed set — a strict
// improvement for Add, which starts from a blank draft.)
// ============================================================
extension Ingredient {

    mutating func applyParsed(_ p: ParsedIngredient) {
        if !p.name.isEmpty { name = p.name }
        if let v = p.brand    { brand = v }
        if let v = p.fullName { fullName = v }
        if let v = p.url      { url = v }
        if let v = p.ingredientsList { ingredients = v }
        if let v = p.allergens       { allergens = v }

        if let v = p.servingSize      { servingSize = v }

        if p.consumptionUnit != nil { consumptionUnit = p.consumptionUnitEnum }
        if let v = p.consumptionGrams { consumptionGrams = v }

        // Macros + V&M — every scannable nutrient in the catalog.
        for d in NutrientCatalog.scannable {
            if let v = p[keyPath: d.parsed!] {
                self[keyPath: d.ingredient] = v
            }
        }
    }
}
