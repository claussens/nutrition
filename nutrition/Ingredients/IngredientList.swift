import SwiftUI

struct IngredientList: View {

    @EnvironmentObject var ingredientMgr: IngredientMgr
    @EnvironmentObject var mealIngredientMgr: MealIngredientMgr
    @EnvironmentObject var foodMgr: FoodMgr
    @EnvironmentObject var foodCompositeMgr: FoodCompositeMgr

    // Pull-to-refresh outcome (config refresh from nutrition-config).
    // Same Feedback the hamburger "Refresh data" item shows.
    @State private var refreshFeedback: ConfigSync.Feedback? = nil
    @State private var showTokenSheet = false

    // Prep list granularity.
    //   .composite  — list FoodComposites (PB&J, Wrap, …) + create
    //   .food       — collapsed Food rows (default)
    //   .ingredient — every individual Ingredient incl. all variants
    enum PrepMode { case composite, food, ingredient }
    @State private var prepMode: PrepMode = .food

    // Sort applied to all three tabs. Name is alphabetical; the
    // others are per-100g (cost = price per 100g), highest first.
    enum SortBy: String, CaseIterable, Identifiable {
        case name = "Name"
        case protein = "Protein"
        case carbs = "Carbs"
        case fat = "Fat"
        case cost = "Cost/100g"
        var id: String { rawValue }
    }
    @State private var sortBy: SortBy = .name

    // Memoized row list. getIngredientList() dedups + sorts the
    // ingredient source on every call; calling it inline in ForEach
    // re-ran that work on every SwiftUI render. Instead we cache the
    // result here and recompute it only when an input that affects the
    // list's membership or order actually changes — driven by the
    // .onAppear / .onChange hooks on the List below.
    //
    // Recompute triggers:
    //   * prepMode / sortBy        — @State, observed directly
    //   * ingredientMgr.ingredients — observed via .count
    //   * a pull-to-refresh that applied new config
    //   * .onAppear                 — catches a refresh run from the
    //                                 Meal tab's menu, and the foodMgr
    //                                 grouping data, which aren't
    //                                 observable from here.
    @State private var rows: [Ingredient] = []

    // Non-nil while the new-composite builder sheet is shown.
    @State private var showCompositeBuilder = false

    // Non-nil while editing an existing composite (chevron tapped).
    @State private var editComposite: FoodComposite? = nil

    var body: some View {
        VStack(spacing: 0) {

            // Pinned header: stays put while the List below scrolls.
            Picker("View", selection: $prepMode) {
                Text("Composite").tag(PrepMode.composite)
                Text("Food").tag(PrepMode.food)
                Text("Ingredient").tag(PrepMode.ingredient)
            }
              .pickerStyle(.segmented)
              .padding(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))

            List {

            if prepMode == .composite {
                compositeSection
            } else {
            ForEach(rows) { ingredient in
                // Ingredient data is read-only in the app (authored in
                // nutrition-config); the row's only action is the tap
                // that toggles the ingredient as an active member of
                // its Food (green) vs inactive (black). Explicit
                // .frame(height: 28) keeps the row from collapsing.
                HStack(spacing: 0) {
                    // Name + tiny brand subtext.
                    VStack(alignment: .leading, spacing: 1) {
                        Text(displayName(ingredient))
                          .font(.callout)
                          .foregroundColor(statusColor(for: ingredient))
                        if !ingredient.brand.isEmpty {
                            Text(ingredient.brand)
                              .font(.caption2)
                              .foregroundColor(Color.theme.blackWhiteSecondary)
                        }
                    }
                      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                      .contentShape(Rectangle())
                      .onTapGesture { toggleFoodActive(ingredient) }

                    // Far-right value of whatever metric we're sorted
                    // by (none when sorted by name/category).
                    if let m = metricText(sortMetric(forRow: ingredient,
                                                     mode: sortBy),
                                          unit: foodMgr.consumptionUnit(for: ingredient)) {
                        Text(m)
                          .font(.caption)
                          .foregroundColor(Color.theme.blackWhiteSecondary)
                          .frame(alignment: .trailing)
                          .layoutPriority(1)
                          .padding(.trailing, 6)
                    }
                }
                  .frame(height: 28)
            }
              .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
            }
            }
              .listStyle(.plain)
              .environment(\.defaultMinListRowHeight, 5)
              // Composite mode is a short list (a handful of recipes);
              // cap it at the top ~20% of the screen rather than
              // letting it stretch full-height.
              .frame(maxHeight: prepMode == .composite
                                  ? UIScreen.main.bounds.height * 0.20
                                  : .infinity)
              // Refresh the memoized row list only when an input that
              // affects membership/order changes (see `rows`).
              .onAppear { rows = getIngredientList() }
              .onChange(of: prepMode) { _ in rows = getIngredientList() }
              .onChange(of: sortBy) { _ in rows = getIngredientList() }
              .onChange(of: ingredientMgr.ingredients.count) { _ in
                  rows = getIngredientList()
              }
              // Pull down to fetch nutrition-config from GitHub. The
              // managers reload themselves when ConfigStore applies,
              // so only the memoized rows need a nudge here.
              .refreshable {
                  let f = await ConfigSync.refreshWithFeedback()
                  rows = getIngredientList()
                  refreshFeedback = f
              }
            if prepMode == .composite { Spacer() }
        }
          .alert(refreshFeedback?.title ?? "",
                 isPresented: Binding(get: { refreshFeedback != nil },
                                      set: { if !$0 { refreshFeedback = nil } }),
                 presenting: refreshFeedback) { f in
              if f.needsToken {
                  Button("Configure token\u{2026}") { showTokenSheet = true }
              }
              Button("OK", role: .cancel) { }
          } message: { f in
              Text(f.message)
          }
          .sheet(isPresented: $showTokenSheet) {
              TokenConfigSheet()
          }
          .toolbar {
              ToolbarItem(placement: .principal) {
                  // Centered cluster: adjustments link + sort menu.
                  HStack(spacing: 22) {
                      NavigationLink(destination: AdjustmentList()) {
                          Image(systemName: "slider.horizontal.3")
                      }

                      Menu {
                          Picker("Sort", selection: $sortBy) {
                              ForEach(SortBy.allCases) { s in
                                  Text(s.rawValue).tag(s)
                              }
                          }
                      } label: {
                          Image(systemName: "arrow.up.arrow.down")
                      }
                  }
                    .foregroundColor(Color.theme.blueYellow)
              }
              // Composites are meal-level groupings the app still owns;
              // foods and ingredients come from nutrition-config, so
              // only the Composite segment gets an Add.
              if prepMode == .composite {
                  ToolbarItem(placement: .primaryAction) {
                      Button("Add") { showCompositeBuilder = true }
                        .foregroundColor(Color.theme.blueYellow)
                  }
              }
          }
          .sheet(isPresented: $showCompositeBuilder) {
              CompositeBuilder(foods: foodMgr.namesSorted) { name, components in
                  foodCompositeMgr.create(name: name, components: components)
              }
          }
          .sheet(item: $editComposite) { comp in
              CompositeBuilder(existing: comp, foods: foodMgr.namesSorted) { name, components in
                  foodCompositeMgr.update(
                      FoodComposite(id: comp.id, name: name, components: components))
              } onDelete: {
                  foodCompositeMgr.remove(name: comp.name)
              }
          }
    }

    // Composite mode: list FoodComposites (tap toggles into the
    // meal, like an ingredient row) plus a create entry.
    @ViewBuilder
    private var compositeSection: some View {
        ForEach(sortedComposites()) { comp in
            HStack(spacing: 8) {
                Text(comp.name)
                  .font(.callout)
                  .foregroundColor(compositeInMeal(comp) ? Color.theme.manual
                                                         : Color.theme.blackWhite)
                  .contentShape(Rectangle())
                  .onTapGesture { toggleComposite(comp) }
                Text(comp.components.map { $0.foodName }.joined(separator: " + "))
                  .font(.caption2)
                  .foregroundColor(Color.theme.blackWhiteSecondary)
                  .lineLimit(1)
                  .frame(maxWidth: .infinity, alignment: .trailing)
                // Summed metric for the active sort (none for name).
                if let m = metricText(compositeMetric(comp, mode: sortBy)) {
                    Text(m)
                      .font(.caption)
                      .foregroundColor(Color.theme.blackWhiteSecondary)
                      .layoutPriority(1)
                }
                // Chevron → edit, mirroring the ingredient rows.
                Button {
                    editComposite = comp
                } label: {
                    Image(systemName: "chevron.right")
                      .font(.caption2)
                      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                      .contentShape(Rectangle())
                }
                  .buttonStyle(.borderless)
                  .foregroundColor(Color.theme.blackWhiteSecondary)
                  .frame(width: 30)
            }
              .frame(height: 28)
              .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
        }
    }

    private func compositeInMeal(_ c: FoodComposite) -> Bool {
        mealIngredientMgr.getByName(name: c.name) != nil
    }

    private func defaultVariant(forFood food: String) -> String {
        foodMgr.getByName(name: food)?.currentIngredientName
            ?? ingredientMgr.getAll().first { $0.foodName == food }?.name
            ?? food
    }

    private func toggleComposite(_ c: FoodComposite) {
        if let mi = mealIngredientMgr.getByName(name: c.name) {
            mealIngredientMgr.delete(mi)
            return
        }
        let parts = c.components.map { comp in
            MealCompositePart(foodName: comp.foodName,
                              selectedVariantName: defaultVariant(forFood: comp.foodName),
                              amount: comp.amount)
        }
        mealIngredientMgr.create(name: c.name, amount: 0,
                                 adjustment: Constants.Manual,
                                 compositeParts: parts)
    }


    // Collapse grouped ingredients to one row per group. The
    // representative is the group's default member; the row DISPLAYS
    // the group name.
    func getIngredientList() -> [Ingredient] {
        let all = ingredientMgr.getAll()
        if prepMode == .ingredient {
            // Expanded: every Ingredient, including each Food's
            // variants, shown under its own name.
            return applySort(all)
        }
        var result: [Ingredient] = []
        var seenGroups = Set<String>()
        for ing in all {
            if ing.foodName.isEmpty {
                result.append(ing)
                continue
            }
            if seenGroups.contains(ing.foodName) { continue }
            seenGroups.insert(ing.foodName)
            if let g = foodMgr.getByName(name: ing.foodName),
               let def = ingredientMgr.getByName(name: g.currentIngredientName) {
                result.append(def)
            } else {
                result.append(ing)
            }
        }
        return applySort(result)
    }


    // The ingredient's category rank, resolved through its Food.
    // Foodless ingredients sort last (Int.max).
    private func typeRank(_ ing: Ingredient) -> Int {
        foodMgr.type(of: ing)?.sortRank ?? Int.max
    }

    // ============================================================
    // Single source of truth for the sortable metric.
    //
    // The macro metrics are per-100g (matching the original sort and
    // the on-screen "highest first" intent). Cost is per the unit the
    // food is actually consumed in: weighed foods (consumptionUnit
    // .gram) use the cost-per-serving basis; counted foods (pills,
    // drinks, eggs…) use cost per ONE consumption unit
    // (costPerGram × consumptionGrams) — $/g is meaningless for those.
    // The sort key and the number shown on the row are the same value.
    //
    // `nil` means "no value for this row + mode" (e.g. name mode, or
    // an unresolvable Food). Callers display nothing and sort these
    // rows last.
    // ============================================================
    private func ingredientMetric(_ ing: Ingredient, mode: SortBy) -> Double? {
        switch mode {
        case .name:    return nil
        case .protein: return ing.protein100
        case .carbs:   return ing.netCarbs100
        case .fat:     return ing.fat100
        case .cost:
            return foodMgr.consumptionUnit(for: ing) == .gram
                ? ing.costPerServing
                : ing.costPerGram * foodMgr.consumptionGrams(for: ing)
        }
    }

    // Composite metric = sum over each component's resolved (default
    // variant) ingredient. Cost sums each component's contributed
    // cost-per-serving; macros sum the per-100g values — same per-
    // component basis as a plain ingredient row, so the displayed
    // total matches the sort key.
    private func compositeMetric(_ c: FoodComposite, mode: SortBy) -> Double? {
        guard mode != .name else { return nil }
        var total = 0.0
        var resolvedAny = false
        for comp in c.components {
            guard let ing = ingredientMgr.getByName(
                    name: defaultVariant(forFood: comp.foodName)),
                  let v = ingredientMetric(ing, mode: mode) else { continue }
            total += v
            resolvedAny = true
        }
        return resolvedAny ? total : nil
    }

    // The metric for any row kind, resolved for display + sorting.
    //   * Ingredient tab row  -> the ingredient itself
    //   * Food (group) row    -> already resolved to the Food's
    //                            current ingredient by
    //                            getIngredientList(), so use it as-is
    private func sortMetric(forRow ing: Ingredient, mode: SortBy) -> Double? {
        ingredientMetric(ing, mode: mode)
    }

    // Right-aligned trailing label for a row, or nil when the active
    // sort has no per-row number (name/category). Macros -> "12.3 g",
    // cost -> "$1.23".
    private func metricText(_ value: Double?, unit: Unit? = nil) -> String? {
        guard let value = value else { return nil }
        if sortBy == .cost {
            // Counted foods read "$0.34/cap"; weighed foods and
            // composites (unit nil/.gram) stay a bare "$1.23".
            if let u = unit, u != .gram {
                return String(format: "$%.2f/%@", value, u.singularForm)
            }
            return String(format: "$%.2f", value)
        }
        return "\(value.formattedString(1)) g"
    }

    // Sort comparator helper: rows with a value rank by value
    // (highest first); rows with no value sort last, consistently.
    private func metricBefore(_ a: Double?, _ b: Double?) -> Bool {
        switch (a, b) {
        case let (.some(x), .some(y)): return x > y
        case (.some, .none):           return true
        case (.none, .some):           return false
        case (.none, .none):           return false
        }
    }

    // Shared sort for the Food and Ingredient tabs. Name groups by
    // the Food's category (sortRank) then name; protein / carbs /
    // fat / cost go through the shared sortMetric so the order always
    // matches the number rendered on the row.
    private func applySort(_ items: [Ingredient]) -> [Ingredient] {
        switch sortBy {
        case .name:
            return items.sorted {
                if typeRank($0) != typeRank($1) {
                    return typeRank($0) < typeRank($1)
                }
                let s0 = foodMgr.seedOrder(of: $0)
                let s1 = foodMgr.seedOrder(of: $1)
                if s0 != s1 { return s0 < s1 }
                return displayName($0) < displayName($1)
            }
        default:
            return items.sorted {
                metricBefore(sortMetric(forRow: $0, mode: sortBy),
                             sortMetric(forRow: $1, mode: sortBy))
            }
        }
    }

    private func sortedComposites() -> [FoodComposite] {
        if sortBy == .name {
            return foodCompositeMgr.composites.sorted { $0.name < $1.name }
        }
        return foodCompositeMgr.composites.sorted {
            metricBefore(compositeMetric($0, mode: sortBy),
                         compositeMetric($1, mode: sortBy))
        }
    }


    // What the row shows: group name for grouped ingredients,
    // otherwise the ingredient's own name.
    private func displayName(_ ing: Ingredient) -> String {
        if prepMode == .ingredient { return ing.name }
        return ing.foodName.isEmpty ? ing.name : ing.foodName
    }

    // Prep page color: green when this Food/ingredient is active in
    // the repertoire (its Ingredient.foodActive flag is on — the
    // flag the tap toggles, and the flag that gates whether
    // the Food appears in the Meal page's eye add-list); black
    // otherwise. Meal membership is the Meal page's concern now, not
    // this one. A collapsed Food row resolves through the Food's
    // current member ingredient.
    private func foodActive(for ingredient: Ingredient) -> Bool {
        if prepMode == .ingredient { return ingredient.foodActive }
        if ingredient.foodName.isEmpty { return ingredient.foodActive }
        // Collapsed Food row: active if ANY member is foodActive.
        return ingredientMgr.getAll().contains {
            $0.foodName == ingredient.foodName && $0.foodActive
        }
    }


    private func statusColor(for ingredient: Ingredient) -> Color {
        foodActive(for: ingredient) ? Color.theme.manual : Color.theme.blackWhite
    }


    // Prep tap: flip ONLY this ingredient's repertoire-active
    // (foodActive) flag. It does NOT add or remove a meal row —
    // adding a Food to the meal is the Meal page's eye affordance.
    private func toggleFoodActive(_ ingredient: Ingredient) {
        ingredientMgr.toggleFoodActive(name: ingredient.name)
        rows = getIngredientList()
    }
}

struct IngredientsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            IngredientList()
              .environmentObject(IngredientMgr())
        }
    }
}


// ============================================================
// CompositeBuilder — create a new FoodComposite from existing
// Foods. Pick components, set each amount, name it, Save.
// ============================================================
struct CompositeBuilder: View {

    @Environment(\.presentationMode) private var presentationMode

    let foods: [String]
    let existing: FoodComposite?
    let onSave: (String, [CompositeComponent]) -> Void
    let onDelete: (() -> Void)?

    @State private var name = ""
    @State private var included: Set<String> = []
    @State private var amounts: [String: Double] = [:]

    init(existing: FoodComposite? = nil,
         foods: [String],
         onSave: @escaping (String, [CompositeComponent]) -> Void,
         onDelete: (() -> Void)? = nil) {
        self.existing = existing
        self.foods = foods
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Name")) {
                    TextField("Composite name", text: $name)
                      .autocorrectionDisabled()
                }
                Section(header: Text("Components")) {
                    ForEach(foods, id: \.self) { f in
                        HStack {
                            Button {
                                if included.contains(f) {
                                    included.remove(f)
                                } else {
                                    included.insert(f)
                                    if amounts[f] == nil { amounts[f] = 1 }
                                }
                            } label: {
                                Image(systemName: included.contains(f)
                                      ? "checkmark.circle.fill" : "circle")
                            }
                              .buttonStyle(.borderless)
                              .foregroundColor(Color.theme.blueYellow)
                            Text(f)
                            Spacer()
                            if included.contains(f) {
                                Stepper(value: Binding(
                                    get: { amounts[f] ?? 1 },
                                    set: { amounts[f] = max(0, $0) }
                                ), in: 0...100, step: 1) {
                                    Text(amountText(amounts[f] ?? 1))
                                      .frame(minWidth: 28)
                                }
                                  .labelsHidden()
                                  .fixedSize()
                            }
                        }
                    }
                }
                if existing != nil, let onDelete = onDelete {
                    Section {
                        Button(role: .destructive) {
                            onDelete()
                            presentationMode.wrappedValue.dismiss()
                        } label: {
                            Label("Delete composite", systemImage: "trash")
                              .foregroundColor(Color.theme.red)
                        }
                    }
                }
            }
              .navigationTitle(existing == nil ? "New composite" : "Edit composite")
              .navigationBarTitleDisplayMode(.inline)
              .onAppear {
                  guard let e = existing, name.isEmpty, included.isEmpty else { return }
                  name = e.name
                  included = Set(e.components.map { $0.foodName })
                  amounts = Dictionary(uniqueKeysWithValues:
                      e.components.map { ($0.foodName, $0.amount) })
              }
              .toolbar {
                  ToolbarItem(placement: .cancellationAction) {
                      Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(Color.theme.blueYellow)
                  }
                  ToolbarItem(placement: .confirmationAction) {
                      Button("Save") {
                          let comps = foods
                            .filter { included.contains($0) }
                            .map { CompositeComponent(foodName: $0,
                                                      amount: amounts[$0] ?? 1) }
                          let trimmed = name.trimmingCharacters(in: .whitespaces)
                          if !trimmed.isEmpty && !comps.isEmpty {
                              onSave(trimmed, comps)
                          }
                          presentationMode.wrappedValue.dismiss()
                      }
                        .foregroundColor(Color.theme.blueYellow)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty
                                  || included.isEmpty)
                  }
              }
        }
    }

    private func amountText(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }
}
