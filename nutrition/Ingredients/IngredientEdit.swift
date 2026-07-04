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
// Shared Vitamins & Minerals entry form. Both screens build the
// row list from NutrientCatalog.vmFormRows, so the row set and
// order live in the catalog. A single dynamic ForEach lays out
// however many rows the catalog defines (the old hard-coded
// 0..<10/10..<20/20..<22 groups crashed if the count changed).
// ============================================================
struct VitaminMineralForm: View {
    // Rows in display order. Built by each screen from its own
    // bindings; this view only lays them out.
    let rows: [(String, Binding<Double>)]

    var body: some View {
        Section(header: Text("Vitamins and Minerals")) {
            ForEach(rows.indices, id: \.self) { i in
                NameValue(rows[i].0, rows[i].1, edit: true)
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
    // The in-flight verify Task, held so a re-tap or dismissing the
    // screen cancels it instead of leaving it running.
    @State private var verifyTask: Task<Void, Never>? = nil

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
            nameSection
            IngredientFormSections(ingredient: $ingredient,
                                   mode: .edit,
                                   newFoodType: $newFoodType)
            verifySection
            autoAdjustSection
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
          .onDisappear { verifyTask?.cancel() }
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

extension IngredientEdit {

    // Apply LLM-parsed values to the bound `ingredient` via the
    // shared Ingredient.applyParsed (IngredientFormSections.swift) —
    // only fields the LLM actually filled in (non-nil) are touched,
    // so any existing values are preserved when the label didn't
    // show them.
    fileprivate func applyPrefill() {
        guard let p = prefill else { return }
        ingredient.applyParsed(p)
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

    // Edit-only header: the Food picker + variant Name composition.
    // Add has no saved name to decompose, so this stays here rather
    // than in the shared IngredientFormSections.
    private var nameSection: some View {
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
                    // formattedString instead of Int(_) — the Int
                    // initializer traps on non-finite/huge doubles.
                    Label("Auto-adjust: +\(rule.amount.formattedString(0)) per cycle",
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
            // %.0f instead of Int(_) — the Int initializer traps on
            // non-finite/huge doubles.
            return String(format: "%.0f", value)
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
        // One verify in flight at a time — cancel any prior run, and
        // keep the handle so onDisappear cancels it on dismiss.
        verifyTask?.cancel()
        verifyTask = Task {
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
                // A cancelled verify (screen dismissed or superseded
                // by a re-tap) isn't an error — clear the spinner and
                // leave verifyError alone.
                if error is CancellationError || Task.isCancelled {
                    await MainActor.run { isVerifying = false }
                    return
                }
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
