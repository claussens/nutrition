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
    @State var omega3: Double = 0
    @State var vitaminD: Double = 0
    @State var calcium: Double = 0
    @State var iron: Double = 0
    @State var potassium: Double = 0
    @State var vitaminA: Double = 0
    @State var vitaminC: Double = 0
    @State var vitaminE: Double = 0
    @State var vitaminK: Double = 0
    @State var thiamin: Double = 0
    @State var riboflavin: Double = 0
    @State var niacin: Double = 0
    @State var vitaminB6: Double = 0
    @State var folate: Double = 0
    @State var vitaminB12: Double = 0
    @State var pantothenicAcid: Double = 0
    @State var phosphorus: Double = 0
    @State var magnesium: Double = 0
    @State var zinc: Double = 0
    @State var selenium: Double = 0
    @State var copper: Double = 0
    @State var manganese: Double = 0

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
            // Previously the V&M state vars on this view were collected
            // by the form but discarded at save — `create()` was being
            // called with only macro fields.  Pass them through so the
            // values entered actually persist on the new ingredient.
            ingredientMgr.create(name: name,
                                 brand: company,
                                 fullName: product,
                                 url: url,
                                 totalCost: cost,
                                 totalGrams: grams,
                                 servingSize: servingSize,
                                 calories: calories,
                                 fat: fat,
                                 fiber: fiber,
                                 netCarbs: netCarbs,
                                 protein: protein,
                                 omega3: omega3,
                                 zinc: zinc,
                                 vitaminK: vitaminK,
                                 vitaminE: vitaminE,
                                 vitaminD: vitaminD,
                                 vitaminC: vitaminC,
                                 vitaminB6: vitaminB6,
                                 vitaminB12: vitaminB12,
                                 vitaminA: vitaminA,
                                 thiamin: thiamin,
                                 selenium: selenium,
                                 riboflavin: riboflavin,
                                 potassium: potassium,
                                 phosphorus: phosphorus,
                                 pantothenicAcid: pantothenicAcid,
                                 niacin: niacin,
                                 manganese: manganese,
                                 magnesium: magnesium,
                                 iron: iron,
                                 folate: folate,
                                 copper: copper,
                                 calcium: calcium,
                                 consumptionUnit: consumptionUnit,
                                 consumptionGrams: consumptionGrams,
                                 meatAmount: 0,
                                 mealAdjustments: mealAdjustments,
                                 verified: "",
                                 foodName: foodName)
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

        if let v = p.omega3          { omega3 = v }
        if let v = p.vitaminD        { vitaminD = v }
        if let v = p.calcium         { calcium = v }
        if let v = p.iron            { iron = v }
        if let v = p.potassium       { potassium = v }
        if let v = p.vitaminA        { vitaminA = v }
        if let v = p.vitaminC        { vitaminC = v }
        if let v = p.vitaminE        { vitaminE = v }
        if let v = p.vitaminK        { vitaminK = v }
        if let v = p.thiamin         { thiamin = v }
        if let v = p.riboflavin      { riboflavin = v }
        if let v = p.niacin          { niacin = v }
        if let v = p.vitaminB6       { vitaminB6 = v }
        if let v = p.folate          { folate = v }
        if let v = p.vitaminB12      { vitaminB12 = v }
        if let v = p.pantothenicAcid { pantothenicAcid = v }
        if let v = p.phosphorus      { phosphorus = v }
        if let v = p.magnesium       { magnesium = v }
        if let v = p.zinc            { zinc = v }
        if let v = p.selenium        { selenium = v }
        if let v = p.copper          { copper = v }
        if let v = p.manganese       { manganese = v }
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
    // Row layout/order lives in the shared VitaminMineralForm.
    private var vitaminAndMineralsSection: some View {
        VitaminMineralForm(rows: [
            ("Omega-3", $omega3),
            ("Vitamin D", $vitaminD),
            ("Calcium", $calcium),
            ("Iron", $iron),
            ("Potassium", $potassium),
            ("Vitamin A", $vitaminA),
            ("Vitamin C", $vitaminC),
            ("Vitamin E", $vitaminE),
            ("Vitamin K", $vitaminK),
            ("Thiamin", $thiamin),
            ("Vitamin B6", $vitaminB6),
            ("Folate", $folate),
            ("Vitamin B12", $vitaminB12),
            ("Pantothenic Acid", $pantothenicAcid),
            ("Phosphorus", $phosphorus),
            ("Magnesium", $magnesium),
            ("Zinc", $zinc),
            ("Selenium", $selenium),
            ("Copper", $copper),
            ("Manganese", $manganese),
            ("Niacin", $niacin),
            ("Riboflavin", $riboflavin),
        ])
    }
}
