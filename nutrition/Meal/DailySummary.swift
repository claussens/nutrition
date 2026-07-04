import SwiftUI


struct DailySummary: View {

    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var profileMgr: ProfileMgr
    @EnvironmentObject var macrosMgr: MacrosMgr
    @EnvironmentObject var mealIngredientMgr: MealIngredientMgr
    @EnvironmentObject var ingredientMgr: IngredientMgr
    @EnvironmentObject var foodMgr: FoodMgr
    @EnvironmentObject var vitaminMineralMgr: VitaminMineralMgr
    @EnvironmentObject var dayLogMgr: DayLogMgr

    // Transient "saved" confirmation shown after Log Today.
    @State private var loggedConfirmation = false


    private var todayString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: Date())
    }


    // Same Food→variant resolution the macro engine and the cost
    // breakdown use — keeps this summary consistent with both.
    private var resolver: MealResolver {
        MealResolver(ingredientMgr: ingredientMgr,
                     foodMgr: foodMgr,
                     profile: profileMgr.profile)
    }


    // Sum of cost contributions across the meal ingredients:
    //   (ingredient.totalCost / ingredient.effectiveTotalGrams)
    //     × (mealIngredient.amount × ingredient.consumptionGrams)
    // Unpriced ingredients (effectiveTotalGrams == 0) contribute 0.
    private func mealTotalCost() -> Double {
        mealIngredientMgr.mealIngredients
          .reduce(0) { running, mi in running + mealRowCost(mi) }
    }


    // Cost of a single meal row, using the exact same formula
    // mealTotalCost() applied inline before; extracting it lets the
    // Log Today snapshot capture per-row cost without duplicating
    // the math. Behavior of mealTotalCost() is unchanged (it now
    // sums this).
    private func mealRowCost(_ mi: MealIngredient) -> Double {
        // Category placeholders are not real foods — zero cost.
        if mi.isFoodTypeSlot { return 0 }
        if mi.isComposite {
            return compositeCost(mi, ingredientMgr, foodMgr)
        }
        guard let ing = resolver.resolvedIngredient(mi),
              ing.effectiveTotalGrams > 0 else { return 0 }
        let costPerGram = ing.totalCost / ing.effectiveTotalGrams
        return costPerGram * (mi.amount * foodMgr.consumptionGrams(for: ing))
    }


    // Display unit string for a meal row (resolved ingredient's
    // consumption unit), mirroring how the meal list labels amounts.
    private func mealRowUnit(_ mi: MealIngredient) -> String {
        if mi.isFoodTypeSlot { return "" }
        if mi.isComposite { return Unit.piece.pluralForm }
        guard let ing = resolver.resolvedIngredient(mi) else { return "" }
        let unit = foodMgr.consumptionUnit(for: ing)
        return mi.amount.singular() ? unit.singularForm : unit.pluralForm
    }


    // Assemble today's snapshot from the SAME values this view
    // already displays — macrosMgr.macros for totals, mealRowCost /
    // mealTotalCost for cost, and computeVitaminMineralActuals
    // (identical to vitaminMineralRedRows()'s call) for V&M. No
    // formula is reinvented here.
    private func logToday() {
        let macros = macrosMgr.macros
        let profile = profileMgr.profile

        // Per-row entries. Skip category placeholders (not real
        // foods) — same exclusion the cost/V&M math uses.
        let entries: [DayLogEntry] = mealIngredientMgr.mealIngredients
          .filter { !$0.isFoodTypeSlot }
          .map { mi in
              // Row-aware resolution (selected member → profile pref
              // → Food default) so the snapshot records the variant
              // whose macros were actually counted.
              let resolved = mi.isComposite
                ? mi.name : resolver.currentName(mi)
              return DayLogEntry(
                  id: mi.id,
                  foodName: mi.name,
                  resolvedName: resolved,
                  amount: mi.amount,
                  unit: mealRowUnit(mi),
                  calories: mi.calories,
                  fat: mi.fat,
                  fiber: mi.fiber,
                  netCarbs: mi.netcarbs,
                  protein: mi.protein,
                  cost: mealRowCost(mi)
              )
          }

        let totals = DayLogTotals(
            calories: macros.calories,
            fat: macros.fat,
            fiber: macros.fiber,
            netCarbs: macros.netCarbs,
            protein: macros.protein,
            cost: mealTotalCost()
        )

        // Identical call to the one vitaminMineralRedRows() makes.
        let actuals = computeVitaminMineralActuals(
            mealIngredients: mealIngredientMgr.mealIngredients,
            resolver: resolver
        )
        let age = profile.age
        let gender = profile.gender
        let vitamins: [DayLogVM] = vitaminMineralOrder.map { type in
            let vm = VitaminMineral(name: type, age: age, gender: gender)
            let actual = actuals[type] ?? 0
            let min = vm.min()
            let pct = min > 0 ? (actual / min) * 100 : 0
            return DayLogVM(
                name: vm.name.formattedString(0),
                amount: actual,
                unit: vm.unit().singularForm,
                percentOfMin: pct
            )
        }

        let body = DayLogBody(
            weightLbs: profile.bodyMass,
            age: profile.age,
            // TODO: source real HealthKit active-energy here; for
            // now reuse the Profile field DailySummary displays.
            activeEnergy: profile.activeCaloriesBurned
        )

        dayLogMgr.logToday(entries: entries,
                           totals: totals,
                           vitamins: vitamins,
                           body: body)

        withAnimation { loggedConfirmation = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { loggedConfirmation = false }
        }
    }


    var body: some View {
        let macros = macrosMgr.macros
        let profile = profileMgr.profile

        NavigationView {
            VStack(alignment: .leading, spacing: 10) {

                // Macro + calorie donuts mirroring the meal page's
                // fixed header — opens the summary with the same
                // at-a-glance picture.
                HStack(spacing: 0) {
                    Spacer()
                    Gauge(title: "Fat",      titleFontColor: Color.theme.blackWhite, titleFontSize: 17, macros.fat,                          actualFontSize: 18,                     macros.fatGoal,         annotationFontColor: Color.theme.blueYellow, unit: "grams", progressLineBackground: Color.theme.progressLineBackground,                 scale: 1.18)
                    Spacer()
                    Gauge(title: "NCarbs",   titleFontColor: Color.theme.blackWhite, titleFontSize: 17, macros.netCarbs, actualFontSize: 18, actualPrecision: 1, macros.netCarbsMaximum, annotationFontColor: Color.theme.blueYellow, unit: "grams", progressLineBackground: Color.theme.progressLineBackground, type: .ceiling, scale: 1.18)
                    Spacer()
                    Gauge(title: "Protein",  titleFontColor: Color.theme.blackWhite, titleFontSize: 17, macros.protein,                      actualFontSize: 18,                     macros.proteinGoal,     annotationFontColor: Color.theme.blueYellow, unit: "grams", progressLineBackground: Color.theme.progressLineBackground,                 scale: 1.18)
                    Spacer()
                    Gauge(title: "Calories", titleFontColor: Color.theme.blackWhite, titleFontSize: 17, macros.calories,                     actualFontSize: 18,                     profile.caloriesGoal,   annotationFontColor: Color.theme.blueYellow, unit: "cal",   progressLineBackground: Color.theme.progressLineBackground,                 showGoalDelta: true, secondaryGoal: profile.caloriesGoalUnadjusted, scale: 1.18)
                    Spacer()
                }
                  .frame(height: 165)

                // Body composition — 6 small gauges.  Section label
                // removed since each gauge already has its own title.
                HStack(spacing: 0) {
                    Spacer()
                    Gauge(title: "Weight",   titleFontColor: Color.theme.blackWhite, profile.bodyMass,                actualPrecision: 1, annotationFontColor: Color.theme.blueYellow, unit: "lbs",   progressLineBackground: Color.theme.progressLineBackground, type: .value, scale: 0.7)
                    Gauge(title: "Fat %",    titleFontColor: Color.theme.blackWhite, profile.bodyFatPercentage,       actualPrecision: 1, annotationFontColor: Color.theme.blueYellow, unit: "%",     progressLineBackground: Color.theme.progressLineBackground, type: .value, scale: 0.7)
                    Gauge(title: "BMI",      titleFontColor: Color.theme.blackWhite, profile.bodyMassIndex,           actualPrecision: 1, annotationFontColor: Color.theme.blueYellow,                progressLineBackground: Color.theme.progressLineBackground, type: .value, scale: 0.7)
                    Gauge(title: "Activity", titleFontColor: Color.theme.blackWhite, profile.activeCaloriesBurned,                        annotationFontColor: Color.theme.blueYellow, unit: "cal",   progressLineBackground: Color.theme.progressLineBackground, type: .value, scale: 0.7)
                    Gauge(title: "Deficit",  titleFontColor: Color.theme.blackWhite, Double(profile.calorieDeficit),                      annotationFontColor: Color.theme.blueYellow, unit: "%",     progressLineBackground: Color.theme.progressLineBackground, type: .value, scale: 0.7)
                    Gauge(title: "Ratio",    titleFontColor: Color.theme.blackWhite, profile.proteinRatio,            actualPrecision: 2, annotationFontColor: Color.theme.blueYellow, unit: "g/lbm", progressLineBackground: Color.theme.progressLineBackground, type: .value, scale: 0.7)
                    Spacer()
                }
                  .frame(height: 70)

                // Total dollar cost of today's meal — sum over the
                // active meal ingredients of (cost/gram × grams
                // consumed). Mirrors the per-ingredient breakdown
                // behind the $ icon on the meal page.
                HStack {
                    Text("Meal Cost").font(.callout)
                    Spacer()
                    Text(String(format: "$%.2f", mealTotalCost()))
                      .font(.callout)
                      .foregroundColor(Color.theme.blueYellow)
                }

                // CALORIES and MACROS text sections removed —
                // the four donut gauges at the top of this page
                // already show those numbers.

                // V&M — only the out-of-range ("red") entries, rendered
                // using the same Min | Max | Actual column layout as the
                // full Vitamin/Mineral page so the two views stay
                // visually consistent.  No section label — the
                // "Vitamin/Mineral" column header is itself the heading.
                //
                // reserveChevronSpace: false → the trailing 18pt spacer
                // baked into the header for List/NavigationLink contexts
                // is suppressed here, so the header columns line up with
                // the data values below (no chevron is added in a VStack).
                let redRows = vitaminMineralRedRows()
                if redRows.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                          .foregroundColor(Color.theme.green)
                          .font(.caption)
                        Text("All within range").font(.caption)
                    }
                } else {
                    // Header keeps its trailing chevron reservation
                    // (true) because each row below now ends with an
                    // explicit chevron Image (we're not in a List, so
                    // no auto-chevron — drawing it manually).  Header
                    // and rows therefore both reserve the same 18pt
                    // trail, keeping the Min/Max/Actual columns aligned.
                    VStack(alignment: .leading, spacing: 4) {
                        VitaminMineralRowHeader(reserveChevronSpace: true)
                        ForEach(redRows, id: \.name) { row in
                            NavigationLink(destination: VitaminMineralContributors(nutrient: row.name)) {
                                HStack(spacing: 5) {
                                    VitaminMineralRow(name: row.name,
                                                      min: row.min,
                                                      max: row.max,
                                                      actual: row.actual,
                                                      unit: row.unit)
                                    // Chevron made more prominent so it
                                    // reads as a tappable disclosure
                                    // affordance, not chrome.
                                    Image(systemName: "chevron.right")
                                      .font(.footnote)
                                      .foregroundColor(Color.theme.blueYellow)
                                      .frame(width: 18)
                                }
                                  .contentShape(Rectangle())
                            }
                              .buttonStyle(.plain)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
              .padding(.horizontal, 16)
              .padding(.top, 8)
              .padding(.bottom, 8)
              .navigationTitle(todayString)
              .navigationBarTitleDisplayMode(.inline)
              .toolbar {
                  ToolbarItem(placement: .navigationBarLeading) {
                      Button {
                          logToday()
                      } label: {
                          Label("Log Today", systemImage: "square.and.arrow.down")
                      }
                  }
                  ToolbarItem(placement: .primaryAction) {
                      Button("Done") {
                          presentationMode.wrappedValue.dismiss()
                      }
                  }
              }
              .overlay(alignment: .bottom) {
                  if loggedConfirmation {
                      HStack(spacing: 6) {
                          Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color.theme.green)
                          Text("Logged to History")
                            .font(.callout)
                            .foregroundColor(Color.theme.blackWhite)
                      }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.theme.blackWhite.opacity(0.08))
                        .cornerRadius(10)
                        .padding(.bottom, 24)
                        .transition(.opacity)
                  }
              }
        }
    }


    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
          .font(.caption2)
          .foregroundColor(Color.theme.blackWhiteSecondary)
          .padding(.top, 2)
    }


    @ViewBuilder
    private func valueCell(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption)
            Spacer()
            Text(value).font(.callout)
        }
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(Color.theme.blackWhite.opacity(0.04))
          .cornerRadius(6)
          .frame(maxWidth: .infinity)
    }


    // One row's worth of data for VitaminMineralRow, surfaced only when
    // the nutrient is out of range.  The `max` here is the *displayed*
    // max — 0 for supp-only-UL nutrients (matches VitaminMineralList) so
    // we don't trigger the over-max signal from food-inclusive totals.
    private struct VMRedRow {
        let name: VitaminMineralType
        let min: Double
        let max: Double
        let actual: Double
        let unit: Unit
    }


    // Out-of-range V&M rows in the same display order and using the
    // same min/max/unit conventions as VitaminMineralList.  An entry
    // counts as "red" when actual < min, or when the displayed max
    // applies (i.e. the nutrient isn't in supplementOnlyULNutrients)
    // *and* actual > max.
    private func vitaminMineralRedRows() -> [VMRedRow] {
        let actuals = computeVitaminMineralActuals(
            mealIngredients: mealIngredientMgr.mealIngredients,
            resolver: resolver
        )
        let age = profileMgr.profile.age
        let gender = profileMgr.profile.gender

        var rows: [VMRedRow] = []

        for type in vitaminMineralOrder {
            let vm = VitaminMineral(name: type, age: age, gender: gender)
            let actual = actuals[type] ?? 0
            let min = vm.min()
            let displayedMax = supplementOnlyULNutrients.contains(type) ? 0 : vm.max()

            let belowMin = min > 0 && actual < min
            let aboveMax = displayedMax > 0 && actual > displayedMax

            if belowMin || aboveMax {
                rows.append(VMRedRow(
                    name: type,
                    min: min,
                    max: displayedMax,
                    actual: actual,
                    unit: vm.unit()
                ))
            }
        }

        return rows
    }
}


// `IngredientSourcesForNutrient` removed — its purpose
// (drill into a deficient nutrient from DailySummary to see which
// ingredients could help) is now served by VitaminMineralContributors,
// which adds a "today's meal contributors" section above the all-
// sources list and reformats rows as "<grams-to-RDA>g (<per-100g>)".
