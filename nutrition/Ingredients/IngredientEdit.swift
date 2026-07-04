import SwiftUI


// ============================================================
// Shared Cancel/Save toolbar. Six add/edit screens pasted a
// byte-identical ~18-line `.toolbar { ... }` Cancel/Save block
// (+ keyboard group, Color.theme.blueYellow) alongside
// `.navigationBarBackButtonHidden(true)`. They now all call
// `.cancelSaveToolbar(onCancel:onSave:)`. The optional
// `saveDisabled` covers screens that gate Save; the
// `.padding([.leading,.trailing], -20)` stays at each call site
// since its placement in the modifier chain varies.
// ============================================================
extension View {
    func cancelSaveToolbar(saveDisabled: Bool = false,
                           onCancel: @escaping () -> Void,
                           onSave: @escaping () -> Void) -> some View {
        self
          .navigationBarBackButtonHidden(true)
          .toolbar {
              ToolbarItem(placement: .navigation) {
                  Button("Cancel", action: onCancel)
                    .foregroundColor(Color.theme.blueYellow)
              }
              ToolbarItem(placement: .primaryAction) {
                  Button("Save", action: onSave)
                    .foregroundColor(Color.theme.blueYellow)
                    .disabled(saveDisabled)
              }
              ToolbarItemGroup(placement: .keyboard) {
                  HStack {
                      DismissKeyboard()
                      Spacer()
                      Button("Save", action: onSave)
                        .foregroundColor(Color.theme.blueYellow)
                  }
              }
          }
    }
}


// ============================================================
// Shared "session-scoped edits" note. Ingredients are config-
// owned: they reload from nutrition-config on every launch, so
// runtime edits (including paid Verify-with-AI corrections) do
// NOT survive a relaunch. Shown on the Edit and Verify screens
// so nobody is surprised. An export-to-config flow is future
// work (nutrition.md P3.4).
// ============================================================
struct SessionScopedEditsNote: View {
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Label("Edits last until relaunch", systemImage: "info.circle")
                  .font(.callout)
                  .foregroundColor(Color.theme.blueYellow)
                Text("Ingredient data reloads from nutrition-config at launch. To keep changes, update nutrition-config.")
                  .font(.caption)
                  .foregroundColor(Color.theme.blackWhiteSecondary)
            }
              .padding(.vertical, 4)
        }
    }
}


// ============================================================
// Shared "Low-confidence fields" banner. Byte-identical copies
// previously lived in both IngredientAdd and IngredientEdit.
// ============================================================
struct LowConfidenceBanner: View {
    let fields: [String]
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Label("Low-confidence fields", systemImage: "exclamationmark.triangle.fill")
                  .font(.callout)
                  .foregroundColor(.orange)
                Text(fields.joined(separator: ", "))
                  .font(.caption)
                  .foregroundColor(Color.theme.blackWhiteSecondary)
            }
              .padding(.vertical, 4)
        }
    }
}


// ============================================================
// Shared Vitamins & Minerals entry form. The ~22-row NameValue
// list was duplicated in IngredientAdd (binding to @State vars)
// and IngredientEdit (binding to `$ingredient.X`). Both now pass
// an ordered list of (label, Binding<Double>) rows so the row
// set, order, and grouping live in one place. The 3-group layout
// (10 / 10 / 2) is preserved exactly.
// ============================================================
struct VitaminMineralForm: View {
    // 22 rows in display order. Built by each screen from its own
    // bindings; this view only lays them out.
    let rows: [(String, Binding<Double>)]

    var body: some View {
        Section(header: Text("Vitamins and Minerals")) {
            Group {
                ForEach(0..<10, id: \.self) { i in
                    NameValue(rows[i].0, rows[i].1, edit: true)
                }
            }
            Group {
                ForEach(10..<20, id: \.self) { i in
                    NameValue(rows[i].0, rows[i].1, edit: true)
                }
            }
            Group {
                ForEach(20..<22, id: \.self) { i in
                    NameValue(rows[i].0, rows[i].1, edit: true)
                }
            }
        }
    }
}


struct IngredientEdit: View {

    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var ingredientMgr: IngredientMgr
    @EnvironmentObject var adjustmentMgr: AdjustmentMgr
    @EnvironmentObject var foodMgr: FoodMgr
    @EnvironmentObject var profileMgr: ProfileMgr

    @State private var newGroupName = ""
    // Category for a brand-new Food created from this screen. An
    // existing Food's type is inherited and never edited here.
    @State private var newFoodType: IngredientType = .produce

    @State var ingredient: Ingredient
    @State private var showAutoAdjust: Bool = false

    // Verify-with-AI state. confident macro/V&M corrections are
    // auto-applied + saved immediately; identity/price and any
    // low-confidence fields are collected into `verifyReview` and
    // surfaced in a sheet for explicit accept/skip.
    @State private var isVerifying = false
    @State private var verifyError: String? = nil
    @State private var verifyNote: String? = nil
    @State private var verifyReview: VerifyReview? = nil

    // Identity / price-ish fields are never auto-applied — they
    // always go through review (price is web-approximate; name/
    // brand changes are identity-sensitive).
    private static let alwaysReviewIDs: Set<String> = [
        "name", "brand", "fullName", "url",
        "ingredientsList", "allergens", "price", "packageGrams"
    ]

    // Optional scan inputs. When supplied, the ingredient state is
    // patched on appear with the parsed values, and a diff banner is
    // shown listing which fields are about to change.
    let prefill: ParsedIngredient?
    let diff: ScanDiff?

    init(ingredient: Ingredient,
         prefill: ParsedIngredient? = nil,
         diff: ScanDiff? = nil) {
        self._ingredient = State(initialValue: ingredient)
        self.prefill = prefill
        self.diff = diff
    }

    var body: some View {
        Form {
            SessionScopedEditsNote()
            if let diff = diff, !diff.isEmpty {
                diffBanner(diff)
            }
            if let prefill = prefill, !prefill.lowConfidenceFields.isEmpty {
                LowConfidenceBanner(fields: prefill.lowConfidenceFields)
            }
            avoidSection
            mainSections
            groupSection
            verifySection
            autoAdjustSection
            vitaminAndMineralsSection
            per100GramsSection
        }
          .sheet(isPresented: $showAutoAdjust) {
              AutoAdjustEditor(ingredient: ingredient)
                .environmentObject(adjustmentMgr)
          }
          .sheet(item: $verifyReview) { review in
              VerifyReviewSheet(review: review) { selected in
                  applyReviewSelection(parsed: review.parsed, ids: selected)
              }
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
            // Apply the deferred FoodMgr link here (not in the Food
            // picker's binding setter) so a cancelled edit never
            // mutates FoodMgr. Mirrors IngredientAdd.save().
            if !ingredient.foodName.isEmpty {
                foodMgr.ensure(name: ingredient.foodName,
                               defaultMember: ingredient.name,
                               type: foodMgr.getByName(name: ingredient.foodName)?.type ?? newFoodType)
            }
            ingredientMgr.update(ingredient)
            presentationMode.wrappedValue.dismiss()
        }
    }
}

//struct IngredientEdit_Previews: PreviewProvider {
//    static var previews: some View {
//        NavigationView {
//            IngredientEdit(ingredient: Ingredient(name: "Chicken", productName: "Butcher Box", servingSize: 200, calories: 180, fat: 2, fiber: 1, netCarbs: 0.5, protein: 10, consumptionUnit: .gram, consumptionGrams: 100))
//        }
//    }
//}


extension IngredientEdit {

    // ============================================================
    // Apply LLM-parsed values to the bound `ingredient`. Only
    // touches fields the LLM actually filled in (non-nil), so any
    // existing values are preserved when the label didn't show
    // them.
    // ============================================================
    fileprivate func applyPrefill() {
        guard let p = prefill else { return }

        if !p.name.isEmpty { ingredient.name = p.name }
        if let v = p.brand    { ingredient.brand = v }
        if let v = p.fullName { ingredient.fullName = v }
        if let v = p.url      { ingredient.url = v }
        if let v = p.ingredientsList { ingredient.ingredients = v }
        if let v = p.allergens       { ingredient.allergens = v }

        if let v = p.servingSize      { ingredient.servingSize = v }
        if let v = p.calories         { ingredient.calories = v }
        if let v = p.fat              { ingredient.fat = v }
        if let v = p.saturatedFat     { ingredient.saturatedFat = v }
        if let v = p.transFat         { ingredient.transFat = v }
        if let v = p.cholesterol      { ingredient.cholesterol = v }
        if let v = p.sodium           { ingredient.sodium = v }
        if let v = p.carbohydrates    { ingredient.carbohydrates = v }
        if let v = p.fiber            { ingredient.fiber = v }
        if let v = p.sugar            { ingredient.sugar = v }
        if let v = p.addedSugar       { ingredient.addedSugar = v }
        if let v = p.netCarbs         { ingredient.netCarbs = v }
        if let v = p.protein          { ingredient.protein = v }

        if p.consumptionUnit != nil { ingredient.consumptionUnit = p.consumptionUnitEnum }
        if let v = p.consumptionGrams { ingredient.consumptionGrams = v }

        if let v = p.omega3          { ingredient.omega3 = v }
        if let v = p.vitaminD        { ingredient.vitaminD = v }
        if let v = p.calcium         { ingredient.calcium = v }
        if let v = p.iron            { ingredient.iron = v }
        if let v = p.potassium       { ingredient.potassium = v }
        if let v = p.vitaminA        { ingredient.vitaminA = v }
        if let v = p.vitaminC        { ingredient.vitaminC = v }
        if let v = p.vitaminE        { ingredient.vitaminE = v }
        if let v = p.vitaminK        { ingredient.vitaminK = v }
        if let v = p.thiamin         { ingredient.thiamin = v }
        if let v = p.riboflavin      { ingredient.riboflavin = v }
        if let v = p.niacin          { ingredient.niacin = v }
        if let v = p.vitaminB6       { ingredient.vitaminB6 = v }
        if let v = p.folate          { ingredient.folate = v }
        if let v = p.vitaminB12      { ingredient.vitaminB12 = v }
        if let v = p.pantothenicAcid { ingredient.pantothenicAcid = v }
        if let v = p.phosphorus      { ingredient.phosphorus = v }
        if let v = p.magnesium       { ingredient.magnesium = v }
        if let v = p.zinc            { ingredient.zinc = v }
        if let v = p.selenium        { ingredient.selenium = v }
        if let v = p.copper          { ingredient.copper = v }
        if let v = p.manganese       { ingredient.manganese = v }
    }


    // Top-of-form summary listing every field that will change
    // when the user taps Save. Each row reads "Field: old → new".
    fileprivate func diffBanner(_ diff: ScanDiff) -> some View {
        Section(header: Text("\(diff.changes.count) field\(diff.changes.count == 1 ? "" : "s") will change")) {
            ForEach(diff.changes) { change in
                HStack {
                    Text(change.field)
                      .font(.caption)
                      .foregroundColor(Color.theme.blackWhiteSecondary)
                    Spacer()
                    Text("\(change.oldValue) \u{2192} ")
                      .font(.caption)
                      .foregroundColor(Color.theme.blackWhiteSecondary)
                    + Text(change.newValue)
                      .font(.caption)
                      .foregroundColor(Color.theme.manual)
                }
            }
        }
    }


    @ViewBuilder
    private var avoidSection: some View {
        let hits = AvoidList.allMatches(in: ingredient.ingredients)
        if !hits.isEmpty {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Contains flagged ingredients", systemImage: "exclamationmark.triangle.fill")
                      .font(.callout)
                      .foregroundColor(.orange)
                    Text(hits.map { $0.canonicalName }.joined(separator: ", "))
                      .font(.caption)
                      .foregroundColor(Color.theme.blackWhiteSecondary)
                }
                  .padding(.vertical, 4)
            }
        }
    }


    // The variant portion of the name with the Food prefix and any
    // wrapping parens stripped, so the Food isn't repeated in the
    // Name field. `name` itself stays the canonical key — these are
    // display-only views onto it that recompose on edit.
    static func variant(of name: String, food: String) -> String {
        var s = name
        if !food.isEmpty, s.hasPrefix(food) {
            s = String(s.dropFirst(food.count)).trimmingCharacters(in: .whitespaces)
        }
        if s.hasPrefix("(") && s.hasSuffix(")") && s.count >= 2 {
            s = String(s.dropFirst().dropLast())
        }
        return s
    }

    static func compose(food: String, variant: String) -> String {
        let v = variant.trimmingCharacters(in: .whitespaces)
        let f = food.trimmingCharacters(in: .whitespaces)
        if f.isEmpty { return v }
        if v.isEmpty { return f }
        return "\(f) (\(v))"
    }

    private var variantBinding: Binding<String> {
        Binding(
            get: { Self.variant(of: ingredient.name, food: ingredient.foodName) },
            set: { newVariant in
                let n = Self.compose(food: ingredient.foodName, variant: newVariant)
                if !n.isEmpty { ingredient.name = n }
            }
        )
    }

    private var mainSections: some View {
        Group {
            Section {
                Picker("Food", selection: Binding(
                    get: { ingredient.foodName },
                    set: { newFood in
                        // Recompose name with the variant carried over
                        // from the previous Food prefix. The FoodMgr
                        // mutation (ensure) is deferred to save() so a
                        // cancelled edit leaves FoodMgr untouched.
                        let v = Self.variant(of: ingredient.name,
                                             food: ingredient.foodName)
                        ingredient.foodName = newFood
                        let n = Self.compose(food: newFood, variant: v)
                        if !n.isEmpty { ingredient.name = n }
                    }
                )) {
                    Text("None").tag("")
                    ForEach(foodMgr.namesSorted, id: \.self) { g in
                        Text(g).tag(g)
                    }
                }
                NameValue("Name", variantBinding, edit: true)
            }
            Section(header: Text("Optional Product Details")) {
                NameValue("URL", $ingredient.url, edit: true)
                NameValue("Brand", $ingredient.brand, edit: true)
                NameValue("Cost", $ingredient.totalCost, .dollar, precision: 2, edit: true)
                NameValue("Grams", description: "total ingredient grams in the product", $ingredient.totalGrams, edit: true)
                NameValue("Cost / 100g", description: "computed: cost ÷ grams × 100", $ingredient.costPer100, .dollar, precision: 2)
            }
            Section(header: Text("Macronutrients")) {
                NameValue("Serving Size", $ingredient.servingSize, edit: true)
                NameValue("Calories", $ingredient.calories, .calorie, edit: true)
                NameValue("Fat", $ingredient.fat, edit: true)
                NameValue("Fiber", $ingredient.fiber, edit: true)
                NameValue("Net Carbs", $ingredient.netCarbs, edit: true)
                NameValue("Protein", $ingredient.protein, edit: true)
            }
            Section(header: Text("Preparation/Consumption Unit")) {
                NameValue("Consumption Unit", description: "preferred meal prep/consumption unit", $ingredient.consumptionUnit, options: Unit.ingredientOptions(), control: .picker)
                NameValue("Grams / Consumption Unit", description: "grams per each prep/consumption unit", $ingredient.consumptionGrams, edit: true)
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

    // Group / variant membership. Picking or creating a group makes
    // this ingredient a member; the group is the thing added to a
    // meal and members are swapped via long-press on the meal row.
    // Group-entity changes (create / default) are applied to FoodMgr
    // immediately; the foodName link persists when the ingredient is
    // saved.
    private var isGroupDefault: Bool {
        guard !ingredient.foodName.isEmpty else { return false }
        return foodMgr.getByName(name: ingredient.foodName)?.currentIngredientName == ingredient.name
    }

    private var groupSection: some View {
        Section(header: Text("Food"),
                footer: Text("Optional. Ingredients sharing a Food are collapsed to one meal row; long-press that row in the meal to pick which variant.")
                  .font(.caption2)) {

            Picker("Food", selection: Binding(
                get: { ingredient.foodName },
                set: { newValue in
                    // FoodMgr mutation (ensure) deferred to save() so a
                    // cancelled edit leaves FoodMgr untouched.
                    ingredient.foodName = newValue
                }
            )) {
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
                    foodMgr.ensure(name: trimmed,
                                   defaultMember: ingredient.name,
                                   type: newFoodType)
                    newGroupName = ""
                }
                  .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
                  .foregroundColor(Color.theme.blueYellow)
            }

            if !ingredient.foodName.isEmpty {
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

    // Auto-adjust rule for this ingredient. Tapping opens
    // AutoAdjustEditor (inlined at the bottom of this file). When a
    // rule already exists, the label shows the per-cycle amount; when
    // none exists, the label invites the user to configure one.
    private var autoAdjustSection: some View {
        Section {
            Button {
                showAutoAdjust = true
            } label: {
                if let rule = adjustmentMgr.getByName(name: ingredient.name) {
                    Label("Auto-adjust: +\(Int(rule.amount)) per cycle",
                          systemImage: "gearshape.fill")
                      .foregroundColor(Color.theme.blueYellow)
                } else {
                    Label("Configure auto-adjust\u{2026}",
                          systemImage: "gearshape")
                      .foregroundColor(Color.theme.blueYellow)
                }
            }
        }
    }

    private var per100GramsSection: some View {
        Section {
            NameValue("Calories (per 100g)", $ingredient.calories100)
            NameValue("Fat (per 100g)", $ingredient.fat100)
            NameValue("Fiber (per 100g)", $ingredient.fiber100)
            NameValue("Net Carbs (per 100g)", $ingredient.netCarbs100, precision: 1)
            NameValue("Protein (per 100g)", $ingredient.protein100)
        }
    }

    // V&M fields are always visible — the previous "Add vitamins
    // and minerals" toggle hid them by default, which made it
    // hard to discover that V&M data could be entered at all.
    // Now they show inline; leave a field blank to record nothing.
    // Row layout/order lives in the shared VitaminMineralForm.
    private var vitaminAndMineralsSection: some View {
        VitaminMineralForm(rows: [
            ("Omega-3", $ingredient.omega3),
            ("Vitamin D", $ingredient.vitaminD),
            ("Calcium", $ingredient.calcium),
            ("Iron", $ingredient.iron),
            ("Potassium", $ingredient.potassium),
            ("Vitamin A", $ingredient.vitaminA),
            ("Vitamin C", $ingredient.vitaminC),
            ("Vitamin E", $ingredient.vitaminE),
            ("Vitamin K", $ingredient.vitaminK),
            ("Thiamin", $ingredient.thiamin),
            ("Vitamin B6", $ingredient.vitaminB6),
            ("Folate", $ingredient.folate),
            ("Vitamin B12", $ingredient.vitaminB12),
            ("Pantothenic Acid", $ingredient.pantothenicAcid),
            ("Phosphorus", $ingredient.phosphorus),
            ("Magnesium", $ingredient.magnesium),
            ("Zinc", $ingredient.zinc),
            ("Selenium", $ingredient.selenium),
            ("Copper", $ingredient.copper),
            ("Manganese", $ingredient.manganese),
            ("Niacin", $ingredient.niacin),
            ("Riboflavin", $ingredient.riboflavin),
        ])
    }
}


// =============================================================
// AutoAdjustEditor — moved here from IngredientList.swift so it
// stays in the same compile unit as the screen that presents it
// (IngredientEdit now hosts the gear button + sheet).
// =============================================================
//
// Sheet for configuring (or disabling) the auto-adjust rule for one
// ingredient. Maps directly to AdjustmentMgr's `setAuto` / `clearAuto`.
struct AutoAdjustEditor: View {

    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var adjustmentMgr: AdjustmentMgr

    let ingredient: Ingredient

    @State private var amountText: String = ""
    @State private var maxText: String = ""
    @State private var hasRule: Bool = false


    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text("Add per cycle")
                          .font(.callout)
                        Spacer()
                        TextField("amount", text: $amountText)
                          .keyboardType(.decimalPad)
                          .multilineTextAlignment(.trailing)
                          .frame(maxWidth: 100)
                        Text(unitLabel)
                          .font(.caption)
                          .foregroundColor(Color.theme.blackWhiteSecondary)
                    }
                    HStack {
                        Text("Max (optional)")
                          .font(.callout)
                        Spacer()
                        TextField("none", text: $maxText)
                          .keyboardType(.decimalPad)
                          .multilineTextAlignment(.trailing)
                          .frame(maxWidth: 100)
                        Text(unitLabel)
                          .font(.caption)
                          .foregroundColor(Color.theme.blackWhiteSecondary)
                    }
                } footer: {
                    Text("Generate-meal will add this amount per pass to \(ingredient.name) until the max (if set) is hit, macro goals are reached, or the ingredient is locked to Manual/Done.")
                      .font(.caption2)
                }

                if hasRule {
                    Section {
                        Button(role: .destructive) {
                            adjustmentMgr.clearAuto(name: ingredient.name)
                            presentationMode.wrappedValue.dismiss()
                        } label: {
                            Label("Disable auto-adjust", systemImage: "trash")
                        }
                    }
                }
            }
              .navigationTitle("Auto-adjust: \(ingredient.name)")
              .navigationBarTitleDisplayMode(.inline)
              .toolbar {
                  ToolbarItem(placement: .navigation) {
                      Button("Cancel") {
                          presentationMode.wrappedValue.dismiss()
                      }
                        .foregroundColor(Color.theme.blueYellow)
                  }
                  ToolbarItem(placement: .primaryAction) {
                      Button("Save") {
                          save()
                      }
                        .foregroundColor(Color.theme.blueYellow)
                        .disabled(Double(amountText) == nil)
                  }
              }
              .onAppear {
                  if let rule = adjustmentMgr.getByName(name: ingredient.name) {
                      hasRule = true
                      amountText = formatNumber(rule.amount)
                      maxText = rule.constraints ? formatNumber(rule.maximum) : ""
                  }
              }
        }
    }


    private func save() {
        guard let amount = Double(amountText) else { return }
        // Empty maxText = no cap.
        let maximum: Double? = {
            let trimmed = maxText.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : Double(trimmed)
        }()
        adjustmentMgr.setAuto(name: ingredient.name, amount: amount, maximum: maximum)
        presentationMode.wrappedValue.dismiss()
    }


    // "grams" / "tablespoons" / "pieces" — matches the units the
    // meal-list stepper shows so the user sees the same vocabulary.
    private var unitLabel: String {
        ingredient.consumptionUnit.pluralForm
    }


    private func formatNumber(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }
        return String(value)
    }
}


// =============================================================
// Verify-with-AI: section UI + run/apply logic.
// =============================================================
extension IngredientEdit {

    var verifySection: some View {
        Section {
            Button {
                verify()
            } label: {
                if isVerifying {
                    HStack {
                        ProgressView()
                        Text("Verifying with AI\u{2026}")
                    }
                } else {
                    Label("Verify with AI", systemImage: "sparkles")
                      .foregroundColor(Color.theme.blueYellow)
                }
            }
              .disabled(isVerifying)

            if let note = verifyNote {
                Text(note)
                  .font(.caption)
                  .foregroundColor(Color.theme.blackWhiteSecondary)
            }
            if let err = verifyError {
                Text(err)
                  .font(.caption)
                  .foregroundColor(Color.theme.red)
            }
        } footer: {
            Text("Web-searches the canonical product (Whole Foods first), updates brand/price and re-checks macros & vitamins. Confident nutrition fixes apply automatically; price and uncertain fields go to review.")
              .font(.caption2)
        }
    }


    private func verify() {
        isVerifying = true
        verifyError = nil
        verifyNote = nil
        let snapshot = ingredient
        Task {
            do {
                let parsed = try await NutritionScannerService.verifyByName(snapshot)
                let d = ScanDiff.compute(existing: snapshot, parsed: parsed)
                let low = Set(parsed.lowConfidenceFields)
                var autoIDs = Set<String>()
                var reviewChanges: [ScanDiff.Change] = []
                for c in d.changes {
                    if low.contains(c.id) || Self.alwaysReviewIDs.contains(c.id) {
                        reviewChanges.append(c)
                    } else {
                        autoIDs.insert(c.id)
                    }
                }
                await MainActor.run {
                    if !autoIDs.isEmpty {
                        var updated = ingredient
                        ScanDiff.apply(parsed: parsed, ids: autoIDs, to: &updated)
                        updated.verified = ScanDiff.todayStamp()
                        ingredient = updated
                        ingredientMgr.update(updated)
                    }
                    isVerifying = false
                    if reviewChanges.isEmpty {
                        verifyNote = autoIDs.isEmpty
                          ? "Verified \u{2014} everything already matched."
                          : "Verified \u{2014} \(autoIDs.count) field\(autoIDs.count == 1 ? "" : "s") auto-updated, nothing to review."
                    } else {
                        verifyReview = VerifyReview(parsed: parsed,
                                                    changes: reviewChanges,
                                                    autoAppliedCount: autoIDs.count)
                    }
                }
            } catch {
                await MainActor.run {
                    isVerifying = false
                    verifyError = (error as? NutritionScannerError)?.errorDescription
                      ?? error.localizedDescription
                }
            }
        }
    }


    func applyReviewSelection(parsed: ParsedIngredient, ids: Set<String>) {
        guard !ids.isEmpty else { return }
        var updated = ingredient
        ScanDiff.apply(parsed: parsed, ids: ids, to: &updated)
        updated.verified = ScanDiff.todayStamp()
        ingredient = updated
        ingredientMgr.update(updated)
    }
}


struct VerifyReview: Identifiable {
    let id = UUID()
    let parsed: ParsedIngredient
    let changes: [ScanDiff.Change]
    let autoAppliedCount: Int
}


// Per-row accept/skip for the fields that weren't auto-applied
// (price + anything the model flagged low-confidence). Price is
// deselected by default so the user must opt into a web-sourced
// price; everything else defaults selected.
struct VerifyReviewSheet: View {

    @Environment(\.presentationMode) private var presentationMode
    let review: VerifyReview
    let onApply: (Set<String>) -> Void

    @State private var selected: Set<String> = []

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("\(review.autoAppliedCount) confident field\(review.autoAppliedCount == 1 ? "" : "s") already applied. Review these \u{2014} price comes from a live web search and is approximate.")
                      .font(.caption)
                }
                Section(header: Text("Proposed changes")) {
                    ForEach(review.changes) { c in
                        Button {
                            if selected.contains(c.id) {
                                selected.remove(c.id)
                            } else {
                                selected.insert(c.id)
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: selected.contains(c.id)
                                        ? "checkmark.circle.fill" : "circle")
                                  .foregroundColor(Color.theme.blueYellow)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.field)
                                      .font(.callout)
                                      .foregroundColor(Color.theme.blackWhite)
                                    Text("\(c.oldValue) \u{2192} \(c.newValue)")
                                      .font(.caption)
                                      .foregroundColor(Color.theme.blackWhiteSecondary)
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
              .navigationTitle("Review changes")
              .navigationBarTitleDisplayMode(.inline)
              .toolbar {
                  ToolbarItem(placement: .navigation) {
                      Button("Skip") {
                          presentationMode.wrappedValue.dismiss()
                      }
                        .foregroundColor(Color.theme.blueYellow)
                  }
                  ToolbarItem(placement: .primaryAction) {
                      Button("Apply") {
                          onApply(selected)
                          presentationMode.wrappedValue.dismiss()
                      }
                        .foregroundColor(Color.theme.blueYellow)
                        .disabled(selected.isEmpty)
                  }
              }
              .onAppear {
                  selected = Set(review.changes.map { $0.id })
                    .subtracting(["price"])
              }
        }
    }
}
