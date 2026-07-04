import SwiftUI

struct IngredientAdd: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var ingredientMgr: IngredientMgr
    @EnvironmentObject var adjustmentMgr: AdjustmentMgr
    @EnvironmentObject var mealIngredientMgr: MealIngredientMgr
    @EnvironmentObject var foodMgr: FoodMgr

    // Optional scan result. When non-nil, fields are populated
    // from it on appear, and the names listed in
    // `lowConfidenceFields` get a yellow tint in the form.
    let prefill: ParsedIngredient?

    init(prefill: ParsedIngredient? = nil) {
        self.prefill = prefill
    }

    @State var name: String = ""
    @State var foodName: String = ""
    @State private var newGroupName = ""
    // Category for a brand-new Food created from this screen. An
    // existing Food's type is inherited and never edited here.
    @State private var newFoodType: IngredientType = .produce

    @State var url: String = ""
    @State var company: String = ""
    @State var product: String = ""
    @State var cost: Double = 0
    @State var grams: Double = 0

    @State var servingSize: Double = 0
    @State var calories: Double = 0
    @State var fat: Double = 0
    @State var fiber: Double = 0
    @State var netCarbs: Double = 0
    @State var protein: Double = 0

    @State var consumptionUnit: Unit = .gram
    @State var consumptionGrams: Double = 1.0

    @State var adjustmentCount = 0
    @State var mealAdjustments: [MealAdjustment] = []

    @State var ingredientAdd: Bool = false
    @State var ingredientAmount: Double = 0

    @State var adjustmentAdd: Bool = false
    @State var adjustmentAmount: Double = 0

    @State var vitaminsAndMinerals: Bool = false

    // Non-core nutrient values keyed by NutrientCatalog id — the V&M
    // form rows bind into this, and a scan prefill drops every
    // non-core nutrient it parsed here (including extended macros
    // like saturatedFat that have no form row, which used to be
    // silently discarded on Add). Absent key = nothing recorded (0).
    @State private var nutrientValues: [String: Double] = [:]

    var body: some View {
        Form {
            if let prefill = prefill, !prefill.lowConfidenceFields.isEmpty {
                LowConfidenceBanner(fields: prefill.lowConfidenceFields)
            }
            mainSections
            groupSection
            quickAddSection
            vitaminAndMineralsSection
        }
          .padding([.leading, .trailing], -20)
          .onAppear { applyPrefill() }
          .cancelSaveToolbar(onCancel: cancel, onSave: save)
    }

    func cancel() {
        withAnimation {
            self.presentationMode.wrappedValue.dismiss()
        }
    }

    func save() {
        withAnimation {
            // Core fields come from their own form bindings; every
            // other nutrient (V&M rows + scanned extended macros) is
            // written through its catalog keypath, so a new nutrient
            // needs no change here.
            var ingredient = Ingredient(name: name,
                                        brand: company,
                                        fullName: product,
                                        foodName: foodName,
                                        url: url,
                                        totalCost: cost,
                                        totalGrams: grams,
                                        servingSize: servingSize,
                                        calories: calories,
                                        fat: fat,
                                        fiber: fiber,
                                        netCarbs: netCarbs,
                                        protein: protein,
                                        consumptionUnit: consumptionUnit,
                                        consumptionGrams: consumptionGrams,
                                        meatAmount: 0,
                                        mealAdjustments: mealAdjustments)
            for d in NutrientCatalog.inNutrientsMap {
                if let v = nutrientValues[d.id] {
                    ingredient[keyPath: d.ingredient] = v
                }
            }
            ingredientMgr.add(ingredient)
            if !foodName.isEmpty {
                foodMgr.ensure(name: foodName,
                               defaultMember: name,
                               type: foodMgr.getByName(name: foodName)?.type ?? newFoodType)
            }
            if ingredientAdd {
                mealIngredientMgr.create(name: name,
                                         amount: ingredientAmount)
            }
            if adjustmentAdd {
                adjustmentMgr.create(name: name,
                                     amount: adjustmentAmount,
                                     active: false)
            }
            presentationMode.wrappedValue.dismiss()
        }
    }
}

struct IngredientAdd2_Previews: PreviewProvider {

    static var previews: some View {
        IngredientAdd()
    }
}

extension IngredientAdd {

    // ============================================================
    // Apply LLM-parsed values to the form's @State vars. Only
    // touches fields the LLM actually filled in (non-nil) — a
    // missing field on the parsed side leaves the user-entered
    // (or default-zero) value alone. A non-empty parsed name
    // wins over the blank @State default.
    // ============================================================
    fileprivate func applyPrefill() {
        guard let p = prefill else { return }

        if !p.name.isEmpty { name = p.name }
        if let v = p.brand    { company = v }
        if let v = p.fullName { product = v }
        if let v = p.url      { url = v }

        if let v = p.servingSize      { servingSize = v }
        if let v = p.calories         { calories = v }
        if let v = p.fat              { fat = v }
        if let v = p.fiber            { fiber = v }
        if let v = p.netCarbs         { netCarbs = v }
        if let v = p.protein          { protein = v }

        consumptionUnit = p.consumptionUnitEnum
        if let v = p.consumptionGrams { consumptionGrams = v }

        // Everything beyond the core macros lands in the nutrient
        // dict, keyed by catalog id (applied to the new Ingredient
        // at save).
        for d in NutrientCatalog.inNutrientsMap {
            if let pk = d.parsed, let v = p[keyPath: pk] {
                nutrientValues[d.id] = v
            }
        }
    }


    private var mainSections: some View {
        Group {
            Section {
                NameValue("Name", $name, edit: true)
            }
            Section(header: Text("Optional Product Details")) {
                NameValue("URL", $url, edit: true)
                NameValue("Company", $company, edit: true)
                NameValue("Product", $product, edit: true)
                NameValue("Cost", $cost, .dollar, precision: 2, edit: true)
                NameValue("Grams", description: "total ingredient grams in the product", $grams, edit: true)
            }
            Section(header: Text("Macronutrients")) {
                NameValue("Serving Size", $servingSize, edit: true)
                NameValue("Calories", $calories, .calorie, edit: true)
                NameValue("Fat", $fat, edit: true)
                NameValue("Fiber", $fiber, edit: true)
                NameValue("Net Carbs", $netCarbs, edit: true)
                NameValue("Protein", $protein, edit: true)
            }
            Section(header: Text("Preparation/Consumption Unit")) {
                NameValue("Consumption Unit", description: "preferred meal prep/consumption unit", $consumptionUnit, options: Unit.ingredientOptions(), control: .picker)
                NameValue("Grams / Unit", description: "grams per each prep/consumption unit", $consumptionGrams, edit: true)
            }
        }
    }

    // Group / variant membership. Picking or creating a Food makes
    // this ingredient a member once saved; mirrors IngredientEdit's
    // groupSection. The "default variant" toggle is intentionally
    // omitted here — it keys off a saved ingredient name, which a
    // brand-new ingredient doesn't have until Save.
    private var groupSection: some View {
        Section(header: Text("Food"),
                footer: Text("Optional. Ingredients sharing a Food are collapsed to one meal row; long-press that row in the meal to pick which variant.")
                  .font(.caption2)) {

            Picker("Food", selection: $foodName) {
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
                    foodName = trimmed
                    newGroupName = ""
                }
                  .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
                  .foregroundColor(Color.theme.blueYellow)
            }
        }
    }

    private var quickAddSection: some View {
        Group {
            Section(header: Text("Meal Ingredients Quick Add")) {
                NameValue("Add to Meal Ingredients", $ingredientAdd, control: .toggle)
                if ingredientAdd {
                    NameValue("Ingredient Amount", $ingredientAmount, edit: true)
                }
            }

            Section(header: Text("Meal Adjustments Quick Add")) {
                NameValue("Add to Adjustments", $adjustmentAdd, control: .toggle)
                if adjustmentAdd {
                    NameValue("Adjustment Amount", $adjustmentAmount, edit: true)
                }
            }
        }
    }

    // V&M fields are always visible (toggle gate removed) — see
    // matching note in IngredientEdit.swift.  New ingredients can
    // record V&M values directly without first enabling a toggle.
    // Row set and order live in NutrientCatalog.vmFormRows.
    private var vitaminAndMineralsSection: some View {
        VitaminMineralForm(rows: NutrientCatalog.vmFormRows.map { d in
            (d.label, Binding(
                get: { nutrientValues[d.id] ?? 0 },
                set: { nutrientValues[d.id] = $0 }
            ))
        })
    }
}
