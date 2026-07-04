import SwiftUI
import HealthKit


struct MealList: View {

    @EnvironmentObject var ingredientMgr: IngredientMgr
    @EnvironmentObject var mealIngredientMgr: MealIngredientMgr
    @EnvironmentObject var adjustmentMgr: AdjustmentMgr
    @EnvironmentObject var macrosMgr: MacrosMgr
    @EnvironmentObject var profileMgr: ProfileMgr
    @EnvironmentObject var foodMgr: FoodMgr
    @EnvironmentObject var foodCompositeMgr: FoodCompositeMgr

    // Non-nil while the group member-picker sheet is shown.
    @State private var memberPickerFor: MealIngredient? = nil
    // Non-nil while the composite editor sheet is shown.
    @State private var compositeEditorFor: MealIngredient? = nil
    // Non-nil while the category-placeholder Food picker is shown.
    @State private var foodTypePickerFor: MealIngredient? = nil

    // Non-persistent — supplements default hidden on every launch
    // (you only enable them when you want to look).
    @State private var showSupplements: Bool = false
    // Drives the "add a Food to the meal" picker sheet (the eye
    // affordance). When true, the sheet lists every active Food not
    // currently in the meal; tapping one adds a normal meal row.
    @State private var showAddFoodPicker: Bool = false
    @State var mealConfigureActive = false
    @State var resetMealIngredientsAlert = false
    @State private var showSummary = false
    @State private var detailFor: MealIngredient? = nil
    @State private var entrySheetFor: MealIngredient? = nil
    @State private var vmListActive = false

    // ============================================================
    // LLM scanner state — mirrors IngredientList's wiring so the
    // camera works identically from the Meal page. Capture sheet →
    // ScanRoute → push prefilled Add/Edit (hidden NavigationLink) or
    // present the ambiguous-match chooser.
    // ============================================================
    @State private var showCaptureSheet = false
    @State private var costDetailActive = false
    @State private var scanAddPrefill: ParsedIngredient? = nil
    @State private var scanEditBundle: ScanEditBundle? = nil
    @State private var scanChooser: ScanChooserPayload? = nil

    private var scanAddActive: Binding<Bool> {
        Binding(get: { scanAddPrefill != nil },
                set: { if !$0 { scanAddPrefill = nil } })
    }
    private var scanEditActive: Binding<Bool> {
        Binding(get: { scanEditBundle != nil },
                set: { if !$0 { scanEditBundle = nil } })
    }

    struct ScanEditBundle {
        let existing: Ingredient
        let parsed: ParsedIngredient
        let diff: ScanDiff
    }
    struct ScanChooserPayload: Identifiable {
        let parsed: ParsedIngredient
        let candidates: [Ingredient]
        var id: String { parsed.name }
    }

    private func applyScanRoute(_ route: ScanRoute) {
        switch route {
        case .new(let parsed):
            scanAddPrefill = parsed
        case .update(let existing, let parsed, let diff):
            scanEditBundle = ScanEditBundle(existing: existing, parsed: parsed, diff: diff)
        case .chooser(let parsed, let candidates):
            scanChooser = ScanChooserPayload(parsed: parsed, candidates: candidates)
        }
    }

    // Use cases:
    // - Deactivate a meal ingredient because it's out that will be auto-adjusted
    //
    // Actions:
    // - Manually updating amount removes the pending compensation if it exists
    var body: some View {
        mealListView
          // Plain list style + an explicit grey background eliminates
          // .insetGrouped's mandatory ~35pt section padding above the
          // first row and below the last.  Combined with the fixed
          // safeAreaInset header below, the meal rows now scroll under
          // a stationary grey "card" without any iOS-injected gaps.
          .listStyle(.plain)
          .background(Color(UIColor.systemGroupedBackground))
          .hiddenScrollBackground()
          .refreshable {
              generateMeal()
          }
          .environment(\.defaultMinListRowHeight, 5)
          // Negative horizontal padding removed — that was a hack for
          // .insetGrouped's row insets.  With .plain style the rows now
          // extend full-width naturally; the negative padding was
          // pushing content past the screen edge and clipping the
          // ingredient names on the left and the chevron on the right.
          .background(
            NavigationLink(destination: MealConfigure(), isActive: $mealConfigureActive) {
                Label("Configure", systemImage: "gear")
            })
          // Hide the system navigation bar; replace it with a fixed
          // header (toolbar + Dashboard) injected via .safeAreaInset.
          // Everything in the inset is anchored to the top — it never
          // scrolls with the meal rows below, which was the user's
          // primary ask.
          .navigationBarHidden(true)
          .safeAreaInset(edge: .top, spacing: 0) {
              headerView
          }
          .onAppear {
              generateMeal()
          }
          .alert("Reset Meal Ingredients?",
                 isPresented: $resetMealIngredientsAlert) {
              Button("Cancel", role: .cancel) {
              }
              Button("Reset", role: .destructive) {
                  mealIngredientMgr.resetMealIngredients()
                  generateMeal()
              }
          } message: {
              Text("This will replace your current meal ingredient amounts with the defaults. This can't be undone.")
          }
          .sheet(isPresented: $showSummary) {
              DailySummary()
          }
          .sheet(isPresented: $costDetailActive) {
              NavigationView {
                  IngredientCostDetail()
                    .environmentObject(ingredientMgr)
                    .environmentObject(mealIngredientMgr)
                    .environmentObject(foodMgr)
                    .environmentObject(profileMgr)
              }
          }
          .sheet(isPresented: $showAddFoodPicker) {
              AddFoodToMealSheet(foods: addableActiveFoods()) { foodName in
                  addFoodToMeal(foodName)
              }
          }
          .sheet(item: $entrySheetFor) { mi in
              let unit = getConsumptionUnit(mi)
              NumberEntrySheet(
                  title: "\(mi.name) (\(unit.pluralForm))",
                  initialValue: mi.amount
              ) { newAmount in
                  // Entering an explicit amount is a deliberate
                  // choice — auto-lock the row (Done / blue) so the
                  // next generateMeal won't auto-adjust it away.
                  // Mirrors toggleLock's Black → Blue path.
                  mealIngredientMgr.doneAdjustment(id: mi.id, amount: newAmount)
                  generateMeal()
              }
          }
          .sheet(item: $compositeEditorFor) { mi in
              CompositeEditor(
                  compositeName: mi.name,
                  parts: mi.compositeParts,
                  variants: { food in
                      ingredientMgr.getAll()
                        .filter { $0.foodName == food }
                        .map { $0.name }.sorted()
                  }
              ) { updated in
                  mealIngredientMgr.setCompositeParts(id: mi.id, parts: updated)
                  generateMeal()
              }
          }
          // Long-press on a Food row opens this variant picker
          // immediately (no intermediate tap). Picking applies the
          // variant and becomes the Food's new default.
          .confirmationDialog(
              "Select variant",
              isPresented: Binding(
                  get: { memberPickerFor != nil },
                  set: { if !$0 { memberPickerFor = nil } }
              ),
              titleVisibility: .visible,
              presenting: memberPickerFor
          ) { mi in
              ForEach(groupMembers(mi), id: \.id) { m in
                  Button(!m.brand.isEmpty && !m.name.contains(m.brand)
                         ? "\(m.name) — \(m.brand)" : m.name) {
                      selectGroupMember(mi, member: m.name)
                      memberPickerFor = nil
                  }
              }
          }
          // Tap on a category placeholder opens this Food picker:
          // every Food whose category rawValue == the placeholder's
          // foodType, in the normal Food sort order. Picking one
          // replaces the placeholder with a normal Food row.
          .confirmationDialog(
              "Choose",
              isPresented: Binding(
                  get: { foodTypePickerFor != nil },
                  set: { if !$0 { foodTypePickerFor = nil } }
              ),
              titleVisibility: .visible,
              presenting: foodTypePickerFor
          ) { mi in
              ForEach(foodsForType(mi.foodType), id: \.id) { f in
                  Button(f.name) {
                      replacePlaceholder(mi, withFood: f.name)
                      foodTypePickerFor = nil
                  }
              }
          }
          // Scanner — capture sheet, ambiguous-match chooser, and
          // hidden NavigationLinks that push prefilled Add/Edit.
          // Mirrors IngredientList so behavior is identical from
          // either page.
          .sheet(isPresented: $showCaptureSheet) {
              LabelCaptureSheet { route in
                  applyScanRoute(route)
              }
                .environmentObject(ingredientMgr)
          }
          .sheet(item: $scanChooser) { payload in
              MatchChooserSheet(parsed: payload.parsed,
                                candidates: payload.candidates) { resolved in
                  applyScanRoute(resolved)
              }
          }
          .background(
              Group {
                  NavigationLink(
                      destination: Group {
                          if let p = scanAddPrefill { IngredientAdd(prefill: p) }
                      },
                      isActive: scanAddActive
                  ) { EmptyView() }

                  NavigationLink(
                      destination: Group {
                          if let b = scanEditBundle {
                              IngredientEdit(ingredient: b.existing,
                                             prefill: b.parsed,
                                             diff: b.diff)
                          }
                      },
                      isActive: scanEditActive
                  ) { EmptyView() }
              }
          )
          .background(
              NavigationLink(
                  destination: Group {
                      if let mi = detailFor {
                          MealIngredientDetail(mealIngredient: mi)
                      }
                  },
                  isActive: Binding(
                      get: { detailFor != nil },
                      set: { if !$0 { detailFor = nil } }
                  )
              ) {
                  EmptyView()
              }
          )
          .background(
              NavigationLink(destination: VitaminMineralList(),
                             isActive: $vmListActive) {
                  EmptyView()
              }
          )
    }


    // ----- List of meal rows -----
    // The scrolling meal rows. Each row is delegated to MealRowView,
    // which receives the per-row bindings/closures it needs (the
    // parent retains ownership of all @State). The ForEach identity
    // and ordering are unchanged — displayedMealIngredients() is the
    // single source of truth for what's shown and in what order.
    @ViewBuilder
    private var mealListView: some View {
        List {
            // Dashboard moved out of the List and into the .safeAreaInset
            // header below so the toolbar+macros+calories area is fixed
            // and never scrolls with the meal rows.
            //
            // Ingredient / Amount column header removed — the row's
            // own affordances (name on the left, stepper + chevron on
            // the right) communicate the columns without a label row.

            ForEach(displayedMealIngredients()) { mealIngredient in
                MealRowView(
                    mealIngredient: mealIngredient,
                    isComposite: mealIngredient.isComposite,
                    isFoodTypeSlot: mealIngredient.isFoodTypeSlot,
                    isGroupRow: isGroupRow(mealIngredient),
                    groupMemberCount: groupMembers(mealIngredient).count,
                    consumptionUnit: getConsumptionUnit(mealIngredient),
                    isAuto: isInAutoMode(mealIngredient),
                    nameLabel: { mealNameLabel(mealIngredient) },
                    memberPickerFor: $memberPickerFor,
                    compositeEditorFor: $compositeEditorFor,
                    foodTypePickerFor: $foodTypePickerFor,
                    detailFor: $detailFor,
                    entrySheetFor: $entrySheetFor,
                    onReplicate: {
                        mealIngredientMgr.replicate(id: mealIngredient.id)
                        generateMeal()
                    },
                    onToggleLock: { toggleLock(mealIngredient) },
                    onStep: { direction in stepAmount(mealIngredient, direction: direction) },
                    onDecrementToZero: {
                        mealIngredientMgr.doneAdjustment(id: mealIngredient.id, amount: 0)
                        generateMeal()
                    }
                )
                  // Swipe-trailing — remove this row from the meal
                  // outright (a meal is exactly the rows present). The
                  // Food remains in the repertoire and can be re-added
                  // any time via the eye add-list. The separate
                  // destructive "delete from database" lives on the
                  // Prep page, not here.
                  // minus.circle.fill mirrors IngredientList's
                  // "Unlist" affordance (minus.circle) — same family.
                  // Swipe exposes the otherwise-hidden gestures so they
                  // are discoverable: full-swipe removes; Switch =
                  // long-press member picker; Duplicate = double-tap
                  // replicate (only when there's >1 member, matching
                  // the double-tap rule).
                  .swipeActions(edge: .trailing) {
                      Button(role: .destructive) {
                          mealIngredientMgr.delete(mealIngredient)
                          generateMeal()
                      } label: {
                          Label("Remove", systemImage: "minus.circle.fill")
                      }
                      if !mealIngredient.isComposite && !mealIngredient.isFoodTypeSlot {
                          if isGroupRow(mealIngredient) {
                              Button {
                                  memberPickerFor = mealIngredient
                              } label: {
                                  Label("Switch", systemImage: "arrow.triangle.2.circlepath")
                              }
                                .tint(Color.theme.blueYellow)
                          }
                          if groupMembers(mealIngredient).count > 1 {
                              Button {
                                  mealIngredientMgr.replicate(id: mealIngredient.id)
                                  generateMeal()
                              } label: {
                                  Label("Duplicate", systemImage: "plus.square.on.square")
                              }
                                .tint(.indigo)
                          }
                      }
                  }
            }
              // .onMove(perform: moveAction)
              .onDelete(perform: deleteAction)
              .border(Color.theme.green, width: 0)
              // Compressed vertical insets — fits more ingredients per
              // screen without shrinking the content fonts themselves.
              // Horizontal insets define the row's usable width that
              // GeometryReader sees, which then splits into the
              // 50 / 10 / 20 / 10 / 10 segments above.
              .listRowInsets(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
        }
    }


    // ----- Fixed header (toolbar + Dashboard) -----
    // Injected via .safeAreaInset(edge: .top) so it stays pinned while
    // the meal rows scroll beneath it.
    @ViewBuilder
    private var headerView: some View {
        // Spacing 10 — doubles the prior ~10pt visible gap to
        // ~20pt between toolbar icons and the macro titles.
        VStack(spacing: 10) {

            // ----- Custom compact toolbar -----
            HStack(spacing: 0) {

                // ----- Quick-action icons (kept in the bar) -----

                // Add a Food to the meal. Opens a picker of every
                // active Food (≥1 member with foodActive == true)
                // that is NOT already in the meal; tapping one
                // adds a normal meal row for it.
                Button {
                    showAddFoodPicker = true
                } label: {
                    Image(systemName: "eye")
                }
                  .frame(width: 44)
                  .foregroundColor(Color.theme.blackWhiteSecondary)

                Spacer().frame(width: 18)
                // Reset the meal back to its seeded ingredients.
                Button {
                    resetMealIngredientsAlert = true
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                  .frame(width: 44)
                  .foregroundColor(Color.theme.blackWhiteSecondary)

                Spacer()

                // ----- Hamburger menu (right) -----
                // Secondary actions relocated off the bar as labeled
                // items, plus the config actions (token / refresh).
                HamburgerMenu {
                    Button {
                        showCaptureSheet = true
                    } label: {
                        Label("Scan label", systemImage: "camera.viewfinder")
                    }
                    Button {
                        showSupplements.toggle()
                    } label: {
                        Label(showSupplements ? "Hide supplements" : "Show supplements",
                              systemImage: showSupplements ? "leaf.fill" : "leaf")
                    }
                    Button {
                        vmListActive = true
                    } label: {
                        Label("Vitamins & minerals", systemImage: "pills")
                    }
                    Button {
                        costDetailActive = true
                    } label: {
                        Label("Cost breakdown", systemImage: "dollarsign.circle")
                    }
                    Button {
                        mealConfigureActive.toggle()
                    } label: {
                        Label("Meal settings", systemImage: "gear")
                    }
                }
                  .frame(width: 44)
            }
              .font(.system(size: 22.95))
              .padding(.horizontal, 8)
              .padding(.vertical, 2)

            // ----- Dashboard (macros + calories bar) -----
            // Pulled out of the List so it stays fixed at the top
            // alongside the toolbar.
            Dashboard(caloriesGoal: profileMgr.profile.caloriesGoal,
                      caloriesGoalUnadjusted: profileMgr.profile.caloriesGoalUnadjusted,
                      calories: macrosMgr.macros.calories,
                      fatGoal: profileMgr.profile.fatGoal,
                      netCarbsMaximum: profileMgr.profile.effectiveNetCarbsMaximum,
                      proteinGoal: profileMgr.profile.proteinGoal,
                      fat: macrosMgr.macros.fat,
                      netCarbs: macrosMgr.macros.netCarbs,
                      protein: macrosMgr.macros.protein,
                      showSummary: $showSummary)
              // Dropped 160 → 151pt — halves remaining grey
              // space between the Goal/TDEE labels and the
              // first meal row below.
              .frame(height: 151)
        }
          // Single grey backdrop spans the whole fixed header
          // (toolbar + dashboard).  Same color as the List below,
          // so transitions are seamless.
          .background(Color(UIColor.systemGroupedBackground))
    }


    // Step the meal ingredient's amount by the ingredient's
    // effective step size.  Floors at 0.
    func stepAmount(_ mi: MealIngredient, direction: Double) {
        guard let ingredient = resolvedIngredient(mi) else { return }
        let delta = effectiveStep(for: ingredient, foodMgr: foodMgr) * direction
        let newAmount = max(0, mi.amount + delta)
        applyAmount(mi, newAmount: newAmount)
    }


    // Apply a new amount to this specific meal row. Every row (meat
    // included — meat is no longer special) goes through
    // mealIngredientMgr.manualAdjustment so the change records as a
    // manual override and survives the next generateMeal. Keyed by
    // the row's id so duplicated rows adjust independently.
    func applyAmount(_ mi: MealIngredient, newAmount: Double) {
        mealIngredientMgr.manualAdjustment(id: mi.id, name: mi.name, amount: newAmount)
        generateMeal()
    }


    // Tap on the ingredient name cycles the row through its modes.
    // The transition is keyed off the row's visible color, not its
    // raw adjustment field — Default rows can render green (when
    // auto-eligible) so they need to behave like green rows do.
    //
    //   Auto-eligible:   Green → Black → Blue → (Green again)
    //   Manual-only:     Black → Blue → Black
    func toggleLock(_ mi: MealIngredient) {
        if isInAutoMode(mi) {
            // Green → Black: enter manual mode. Auto-adjust will
            // skip the row from here on. mi.amount captures whatever
            // auto-adjustment landed on (or the seeded amount if
            // auto hadn't fired this cycle).
            mealIngredientMgr.manualAdjustment(id: mi.id, name: mi.name, amount: mi.amount)
        } else if mi.adjustment == Constants.Done {
            // Blue → Default. For auto-eligible ingredients, reset
            // amount to originalAmount so the next generateMeal can
            // re-promote cleanly. Manual-only ingredients keep the
            // user's amount.
            let isAutoEligible = adjustmentMgr.adjustments.contains { $0.name == mi.name }
            mealIngredientMgr.undoDoneAdjustment(id: mi.id, resetAmount: isAutoEligible)
        } else {
            // Black (Manual, or non-eligible Default) → Blue.
            mealIngredientMgr.doneAdjustment(id: mi.id, amount: mi.amount)
        }
        generateMeal()
    }


    // The list of rows the ForEach should render right now. A meal is
    // exactly the rows present; the only view filter is the
    // supplement hide/show toggle.
    func displayedMealIngredients() -> [MealIngredient] {
        let base = mealIngredientMgr.mealIngredients
        let visible = base.filter { showSupplements || !$0.isSupplement }
        // Ordered PURELY by each row's Food position in the Food.swift
        // seed array (the user's salad-building order). Category
        // grouping is intentionally ignored on the meal page. The
        // Food-Type placeholder is forced strictly last; ties (e.g.
        // duplicate rows of the same Food) keep insertion order.
        let pos = Dictionary(
            mealIngredientMgr.mealIngredients.enumerated().map { ($1.id, $0) },
            uniquingKeysWith: { a, _ in a })
        return visible.sorted {
            if $0.isFoodTypeSlot != $1.isFoodTypeSlot { return !$0.isFoodTypeSlot }
            let s0 = mealRowSeedOrder($0)
            let s1 = mealRowSeedOrder($1)
            if s0 != s1 { return s0 < s1 }
            return (pos[$0.id] ?? 0) < (pos[$1.id] ?? 0)
        }
    }


    // The Food seed (append) position for a meal row — the PRIMARY
    // meal-page ordering key (Food.swift array order). Composite /
    // unresolvable rows have no Food, so they sort last (Int.max),
    // just before the Food-Type placeholder.
    private func mealRowSeedOrder(_ mi: MealIngredient) -> Int {
        guard let ing = resolvedIngredient(mi) else { return Int.max }
        return foodMgr.seedOrder(of: ing)
    }


    // Is this row visually green? True when the row either was
    // actually auto-adjusted this cycle (Automatic) OR is a Default
    // row that has an Adjustment rule targeting it (auto-eligible —
    // auto may not have fired due to macro limits, but the user's
    // mental model is still "this row is in auto mode").
    func isInAutoMode(_ mi: MealIngredient) -> Bool {
        if mi.adjustment == Constants.Automatic { return true }
        if mi.adjustment == Constants.Default {
            return adjustmentMgr.adjustments.contains { $0.name == mi.name }
        }
        return false
    }


    // func moveAction(from source: IndexSet, to destination: Int) {
    //     mealIngredientMgr.move(from: source, to: destination)
    // }


    func deleteAction(indexSet: IndexSet) {
        mealIngredientMgr.deleteSet(indexSet: indexSet)
    }


    // The meal-generation engine (goal setting, the adjustment
    // ordering/fitting solver, macro bookkeeping) lives in
    // MealPlanner (MealPlanner.swift) so it is testable without a
    // view hierarchy. This wrapper keeps the UI call sites
    // unchanged and adds the two view-only concerns: the HealthKit
    // profile refresh and the production RNG for the within-group
    // adjustment shuffle.
    var planner: MealPlanner {
        MealPlanner(ingredientMgr: ingredientMgr,
                    mealIngredientMgr: mealIngredientMgr,
                    adjustmentMgr: adjustmentMgr,
                    macrosMgr: macrosMgr,
                    foodMgr: foodMgr,
                    profile: profileMgr.profile)
    }


    func generateMeal() {

        // Attempt to retrieve the body weight and body fat percentage
        // from Health Kit and update the profile if new values are
        // available.
        getBodyWeightAndBodyFatFromHealthKit()

        var rng = SystemRandomNumberGenerator()
        planner.generateMeal(using: &rng)
    }


    func getBodyWeightAndBodyFatFromHealthKit() {
        HealthStore.authorizeHealthKit { (success, error) in
            guard success else {
                let baseMessage = "HealthKit Authorization Failed"
                if let error = error {
                    print("\(baseMessage). Reason: \(error)")
                } else {
                    print(baseMessage)
                }
                return
            }

            // print("HealthKit successfully authorized.")
            if profileMgr.profile.bodyMassFromHealthKit {
                getBodyMass()
            }
            if profileMgr.profile.bodyFatPercentageFromHealthKit {
                getBodyFatPercentage()
            }
            getActiveEnergyBurned()
        }
    }


    func getBodyMass() {
        // print("Getting body mass")
        guard let sampleType = HKSampleType.quantityType(forIdentifier: .bodyMass) else {
            print("Body Mass sample type is no longer available in HealthKit")
            return
        }

        HealthStore.getMostRecentSample(sampleType: sampleType) { (sample, error) in
            guard let sample = sample else {
                if let error = error {
                    print("\(error)")
                }
                return
            }

            let bodyMass = sample.quantity.doubleValue(for: HKUnit.pound())

            if bodyMass != Double(profileMgr.profile.bodyMass) {
                profileMgr.setBodyMass(bodyMass: bodyMass)
            }
        }
    }


    func getBodyFatPercentage() {
        // print("Getting body fat percentage")
        guard let sampleType = HKSampleType.quantityType(forIdentifier: .bodyFatPercentage) else {
            print("Body Fat Percentage sample type is no longer available in HealthKit")
            return
        }

        HealthStore.getMostRecentSample(sampleType: sampleType) { (sample, error) in
            guard let sample = sample else {
                if let error = error {
                    print("\(error)")
                }
                return
            }

            let bodyFatPercentage = (sample.quantity.doubleValue(for: HKUnit.percent())) * 100

            if bodyFatPercentage != Double(profileMgr.profile.bodyFatPercentage) {
                profileMgr.setBodyFatPercentage(bodyFatPercentage: bodyFatPercentage)
            }
        }
    }


    func getActiveEnergyBurned() {
        // print("Getting active energy burned")
        guard let sampleType = HKSampleType.quantityType(forIdentifier: .activeEnergyBurned) else {
            print("Active Energy Burned sample type is no longer available in HealthKit")
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now

        // let energySampleType = HKSampleType.quantityTypeForIdentifier(HKQuantityTypeIdentifierActiveEnergyBurned)
        // let predicate = HKQuery.predicateForSamplesWithStartDate(startDate, endDate: endDate, options: .None)

        // let query = HKSampleQuery(sampleType: energySampleType!, predicate: predicate, limit: 0, sortDescriptors: nil) { (query, results, error) in
        HealthStore.getMostRecentSample(sampleType: sampleType, startDate: startDate) { (sample, error) in
            guard let sample = sample else {
                if let error = error {
                    print("\(error)")
                }
                return
            }

            _ = sample.quantity.doubleValue(for: HKUnit.kilocalorie())

            // TODO: Update once the health kit active calories algorithm is demystified
            // if activeCaloriesBurned != profileMgr.profile.activeCaloriesBurned {
            //     print("Updating active energy burned...")
            //     profileMgr.setActiveEnergyBurned(activeCaloriesBurned: activeCaloriesBurned)
            // }
        }
    }


    func getConsumptionUnit(_ mi: MealIngredient) -> Unit {
        guard let ing = resolvedIngredient(mi) else { return .gram }
        return foodMgr.consumptionUnit(for: ing)
    }


    // Meal-row → Ingredient resolution is owned by MealResolver
    // (MealIngredient.swift) so every consumer — macros here, V&M
    // totals, cost breakdown, daily summary — uses the SAME lookup.
    // These thin wrappers keep existing call sites unchanged.
    var resolver: MealResolver {
        MealResolver(ingredientMgr: ingredientMgr, foodMgr: foodMgr, profile: profileMgr.profile)
    }

    func currentName(_ mi: MealIngredient) -> String {
        resolver.currentName(mi)
    }

    func currentName(forFoodName foodOrName: String) -> String {
        resolver.currentName(forFoodName: foodOrName)
    }

    func resolvedIngredient(_ mi: MealIngredient) -> Ingredient? {
        resolver.resolvedIngredient(mi)
    }


    // Name + brand subtext, mirroring the prep screen exactly:
    // .callout name (inherits the row's mode color, applied by the
    // caller) + .caption2 brand in the secondary color.
    @ViewBuilder
    func mealNameLabel(_ mi: MealIngredient) -> some View {
        let brand = resolvedIngredient(mi)?.brand ?? ""
        VStack(alignment: .leading, spacing: 1) {
            Text(mi.name)
              .font(.callout)
            if !brand.isEmpty {
                Text(brand)
                  .font(.caption2)
                  .foregroundColor(Color.theme.blackWhiteSecondary)
            }
        }
    }

    // Members of the group a meal row represents (for the picker).
    func groupMembers(_ mi: MealIngredient) -> [Ingredient] {
        ingredientMgr.getAll().filter { $0.foodName == mi.name }
    }


    func isGroupRow(_ mi: MealIngredient) -> Bool {
        foodMgr.getByName(name: mi.name) != nil
    }


    func selectGroupMember(_ mi: MealIngredient, member: String) {
        // Per-row selection — store the chosen member on THIS row
        // only (id-keyed). Does NOT mutate the Food global, so other
        // rows of the same Food keep their own members.
        mealIngredientMgr.setSelectedMember(id: mi.id, member: member)
        // Adopt the picked variant's effective preset amount (e.g.
        // Avocado Large 225 g vs Medium 140 g) — ingredient override
        // wins, else the Food-level default. Skip when there's no
        // preset so a user's hand-set amount is preserved.
        if let memberIng = ingredientMgr.getByName(name: member) {
            let amt = foodMgr.effectiveDefaultAmount(for: memberIng, profile: profileMgr.profile)
            if amt > 0 {
                mealIngredientMgr.setAmount(id: mi.id, amount: amt)
            }
        }
        generateMeal()
    }


    // Every Food whose category rawValue matches `type`, in the
    // normal Food sort order (category rank then seed order). Used
    // by the category-placeholder picker. For "meat" this is the 7
    // meat Foods: Beef, Bison, Chicken, Lamb, Pork Chop, Salmon,
    // Top Sirloin Cap (in seed order).
    func foodsForType(_ type: String) -> [Food] {
        foodMgr.foodsSorted.filter { $0.type.rawValue == type }
    }


    // Replace a category placeholder with a normal Food row. Removes
    // the placeholder by id (so it does NOT reappear within this
    // meal) and adds Food X exactly like adding it from the prep
    // screen (IngredientList.promote): the row's `name` is the Food
    // name, amount is the Food's current ingredient's effective
    // default, and isSupplement follows the Food's category. Then
    // regenerates the meal. The placeholder only comes back on
    // Reset Meal (it's seeded in resetMealIngredients()).
    func replacePlaceholder(_ mi: MealIngredient, withFood foodName: String) {
        if let existing = mealIngredientMgr.mealIngredients.first(where: { $0.id == mi.id }) {
            mealIngredientMgr.delete(existing)
        }
        guard let food = foodMgr.getByName(name: foodName) else {
            generateMeal()
            return
        }
        // Mirror IngredientList.promote's grouped-Food branch: start
        // the amount from the Food's current ingredient's effective
        // preset (ingredient override wins, else Food-level default).
        let member = food.currentIngredientName
        let amount = ingredientMgr.getByName(name: member)
            .map { foodMgr.effectiveDefaultAmount(for: $0, profile: profileMgr.profile) } ?? 0
        mealIngredientMgr.create(name: food.name,
                                 amount: amount,
                                 isSupplement: food.type == .supplement)
        generateMeal()
    }


    // The eye add-list source: every ACTIVE Food not currently in
    // the meal. "Active Food" = a Food with ≥1 member ingredient
    // whose Ingredient.foodActive == true. "In the meal" = some
    // present MealIngredient.name == Food.name (a Food already
    // present is not offered; duplicate it via the row double-tap
    // instead). Presented in the normal Food sort order.
    func addableActiveFoods() -> [Food] {
        let inMeal = Set(mealIngredientMgr.mealIngredients.map { $0.name })
        return foodMgr.foodsSorted.filter { food in
            if inMeal.contains(food.name) { return false }
            return ingredientMgr.getAll().contains {
                $0.foodName == food.name && $0.foodActive
            }
        }
    }


    // Add a normal meal row for `foodName` — the same code path the
    // category-placeholder picker uses (IngredientList.promote's
    // grouped-Food branch): the row's `name` is the Food name, the
    // amount is the Food's current ingredient's effective default,
    // and isSupplement follows the Food's category.
    func addFoodToMeal(_ foodName: String) {
        guard let food = foodMgr.getByName(name: foodName) else { return }
        let member = food.currentIngredientName
        let amount = ingredientMgr.getByName(name: member)
            .map { foodMgr.effectiveDefaultAmount(for: $0, profile: profileMgr.profile) } ?? 0
        mealIngredientMgr.create(name: food.name,
                                 amount: amount,
                                 isSupplement: food.type == .supplement)
        generateMeal()
    }


    // Resolve a Food to the variant a composite should start with:
    // its current default member, else any member, else the Food
    // name itself (defensive).
    private func defaultVariant(forFood foodName: String) -> String {
        foodMgr.getByName(name: foodName)?.currentIngredientName
            ?? ingredientMgr.getAll().first { $0.foodName == foodName }?.name
            ?? foodName
    }


    // Add (or toggle off) a composite in the meal. Snapshots each
    // component to its Food's current default variant. Created as
    // Manual so the auto-adjust engine leaves it alone.
    func addComposite(_ composite: FoodComposite) {
        if let existing = mealIngredientMgr.getByName(name: composite.name) {
            mealIngredientMgr.delete(existing)
            generateMeal()
            return
        }
        let parts = composite.components.map { c in
            MealCompositePart(foodName: c.foodName,
                              selectedVariantName: defaultVariant(forFood: c.foodName),
                              amount: c.amount)
        }
        mealIngredientMgr.create(name: composite.name,
                                 amount: 0,
                                 adjustment: Constants.Manual,
                                 compositeParts: parts)
        generateMeal()
    }
}


// ============================================================
// MealRowView — a single meal row. Extracted from MealList's
// body verbatim; the parent owns all @State and threads in only
// the per-row bindings and closures this row needs. Pre-resolved
// derived values (isGroupRow, groupMemberCount, consumptionUnit,
// isAuto, the name label, …) are passed in rather than recomputed
// here so resolution stays centralized in MealList and behavior is
// byte-for-byte identical to the inline version.
//
// Row layout is strict proportional: name 50%, left triangle 10%,
// pill 20%, right triangle 10%, chevron 10%. Each segment's entire
// allocated width is its tap zone (via contentShape) so taps on
// whitespace adjacent to a symbol still hit the right control.
// ============================================================
struct MealRowView<NameLabel: View>: View {

    let mealIngredient: MealIngredient
    let isComposite: Bool
    let isFoodTypeSlot: Bool
    let isGroupRow: Bool
    let groupMemberCount: Int
    let consumptionUnit: Unit
    let isAuto: Bool
    @ViewBuilder let nameLabel: () -> NameLabel

    @Binding var memberPickerFor: MealIngredient?
    @Binding var compositeEditorFor: MealIngredient?
    @Binding var foodTypePickerFor: MealIngredient?
    @Binding var detailFor: MealIngredient?
    @Binding var entrySheetFor: MealIngredient?

    let onReplicate: () -> Void
    let onToggleLock: () -> Void
    let onStep: (Double) -> Void
    let onDecrementToZero: () -> Void

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            HStack(spacing: 0) {
              if isFoodTypeSlot {
                // CATEGORY PLACEHOLDER — visually distinct
                // "pick something" affordance. No stepper, no
                // macros, contributes zero calories. Tapping
                // anywhere on the row opens a Food picker for
                // this category (confirmationDialog below).
                // The #1 gestures (double-tap replicate,
                // long-press member picker, single-tap lock)
                // are intentionally NOT attached here.
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.dashed")
                      .font(.callout)
                    Text("\(mealIngredient.name) — tap to choose")
                      .font(.callout)
                      .italic()
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                      .font(.caption2)
                }
                  .foregroundColor(Color.theme.blackWhiteSecondary)
                  .frame(width: w, alignment: .leading)
                  .contentShape(Rectangle())
                  .onTapGesture {
                      foodTypePickerFor = mealIngredient
                  }
              } else {
                // Just the name — IngredientRow is overkill here
                // (its showMacros/showAmount are both off, and
                // its inner GeometryReader+frame(height: 9) was
                // glueing the text to the top of the 28pt row).
                // Plain Text centers vertically via the HStack's
                // default .center alignment, matching the
                // stepper and chevron.
                if isComposite {
                    // Composite row: long-press opens the
                    // dedicated multi-component editor (too
                    // complex for an inline dropdown). Single
                    // tap still cycles the lock state.
                    nameLabel()
                      .frame(width: w * 0.50, alignment: .leading)
                      .contentShape(Rectangle())
                      .onLongPressGesture {
                          compositeEditorFor = mealIngredient
                      }
                      .onTapGesture {
                          onToggleLock()
                      }
                } else {
                    nameLabel()
                      .frame(width: w * 0.50, alignment: .leading)
                      // contentShape makes the full 50% zone hit-
                      // testable, not just the rendered glyphs.
                      .contentShape(Rectangle())
                      // Double-tap duplicates the row into a new
                      // independent row (same member + amount,
                      // fresh identity) — ONLY for Foods with >1
                      // member; duplicating a single-member Food
                      // makes no sense (nothing to switch the
                      // copy to). Attached before single-tap so
                      // the 2-tap gesture gets priority.
                      .if(groupMemberCount > 1) { view in
                          view.onTapGesture(count: 2) {
                              onReplicate()
                          }
                      }
                      // Group rows: long-press immediately opens
                      // the variant picker (confirmationDialog
                      // below). Lock stays on the single-tap
                      // cycle. The picked member changes ONLY
                      // this row.
                      .if(isGroupRow) { view in
                          view.onLongPressGesture {
                              memberPickerFor = mealIngredient
                          }
                      }
                      .onTapGesture {
                          onToggleLock()
                      }
                }
                if isComposite {
                    // Composites have no single amount; the
                    // stepper slot shows the summed calories
                    // and opens the component editor on tap.
                    Button {
                        compositeEditorFor = mealIngredient
                    } label: {
                        Text("\(Int(mealIngredient.calories)) cals")
                          .font(.callout)
                          .frame(width: w * 0.40, alignment: .center)
                          .contentShape(Rectangle())
                    }
                      .buttonStyle(.borderless)
                } else {
                    AmountStepper(
                    amount: mealIngredient.amount,
                    unit: consumptionUnit,
                    // "Locked" here means Done (blue): inc/dec/pill
                    // are disabled. Manual rows (black) still allow
                    // amount changes; the stepper stays visible and
                    // active for those.
                    isLocked: mealIngredient.adjustment == Constants.Done,
                    isAuto:   isAuto,
                    decrementWidth: w * 0.10,
                    pillWidth:      w * 0.20,
                    incrementWidth: w * 0.10,
                    onDecrement:       { onStep(-1) },
                    onIncrement:       { onStep(+1) },
                    // Hold the ◀ triangle: zero the amount AND
                    // lock the row (Done / blue) in one shot.
                    // doneAdjustment(…, amount: 0) sets both,
                    // so the row immediately renders as the
                    // locked "0 <unit>" blue pill and stops
                    // being auto-adjusted. Same lock path as
                    // the Black → Blue tap-name transition.
                    onDecrementToZero: {
                        onDecrementToZero()
                    },
                    onPillTap:         { entrySheetFor = mealIngredient }
                    )
                }

                Button {
                    detailFor = mealIngredient
                } label: {
                    Image(systemName: "chevron.right")
                      .font(.caption2)
                      // Glyph sits at the right edge (alignment:
                      // .trailing) but the whole 10% zone stays
                      // tappable because contentShape covers
                      // the full frame.
                      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                      .contentShape(Rectangle())
                }
                  .buttonStyle(.borderless)
                  .foregroundColor(Color.theme.blackWhiteSecondary)
                  .frame(width: w * 0.10)
              }
            }
              // Color tells you which mode the row is in:
              //   Green  — Auto mode: either Automatic (was just
              //            auto-adjusted) OR Default with an
              //            adjustment rule targeting it (auto-
              //            eligible, may not have fired this
              //            cycle if macros are full)
              //   Blue   — Done (Constants.Done)
              //   Black  — Manual, or Default without an auto-rule
              // Placeholders keep their own muted/secondary
              // color (applied on the inner HStack above) —
              // the mode-color logic doesn't apply to them.
              .foregroundColor(isFoodTypeSlot ? Color.theme.blackWhiteSecondary :
                                (isAuto ? Color.theme.manual :
                                   (mealIngredient.adjustment == Constants.Done ? Color.theme.blueYellow :
                                      Color.theme.blackWhite)))
        }
          // Explicit row height — GeometryReader has no intrinsic
          // height inside a List row, so without this the row
          // would collapse. 26.6pt = 28 × 0.95 (5% reduction).
          .frame(height: 26.6)
    }
}

//struct MealIngredientList_Previews: PreviewProvider {
//    static var previews: some View {
//        NavigationView {
//            MealIngredientList()
//              .environmentObject(MealIngredientMgr())
//        }
//    }
//}


// ============================================================
// CompositeEditor — the dedicated screen a composite meal row
// opens on long-press. Per component: swap the Food's variant
// and adjust the amount. Changes apply live (onChange fires the
// meal regeneration); Done dismisses.
// ============================================================
struct CompositeEditor: View {

    @Environment(\.presentationMode) private var presentationMode

    let compositeName: String
    let variants: (String) -> [String]
    let onChange: ([MealCompositePart]) -> Void

    @State private var parts: [MealCompositePart]

    init(compositeName: String,
         parts: [MealCompositePart],
         variants: @escaping (String) -> [String],
         onChange: @escaping ([MealCompositePart]) -> Void) {
        self.compositeName = compositeName
        self.variants = variants
        self.onChange = onChange
        _parts = State(initialValue: parts)
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(parts.indices, id: \.self) { i in
                    Section(header: Text(parts[i].foodName)) {

                        Picker("Variant", selection: Binding(
                            get: { parts[i].selectedVariantName },
                            set: { parts[i].selectedVariantName = $0; onChange(parts) }
                        )) {
                            ForEach(variants(parts[i].foodName), id: \.self) { v in
                                Text(v).tag(v)
                            }
                        }

                        HStack {
                            Text("Amount")
                            Spacer()
                            Button {
                                parts[i].amount = max(0, parts[i].amount - 1)
                                onChange(parts)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                              .buttonStyle(.borderless)
                            Text(amountText(parts[i].amount))
                              .frame(minWidth: 44)
                              .multilineTextAlignment(.center)
                            Button {
                                parts[i].amount += 1
                                onChange(parts)
                            } label: {
                                Image(systemName: "plus.circle")
                            }
                              .buttonStyle(.borderless)
                        }
                          .foregroundColor(Color.theme.blueYellow)
                    }
                }
            }
              .navigationTitle(compositeName)
              .navigationBarTitleDisplayMode(.inline)
              .toolbar {
                  ToolbarItem(placement: .confirmationAction) {
                      Button("Done") {
                          presentationMode.wrappedValue.dismiss()
                      }
                        .foregroundColor(Color.theme.blueYellow)
                  }
              }
        }
    }

    private func amountText(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }
}


// ============================================================
// AddFoodToMealSheet — the eye affordance's picker. Lists every
// active Food not currently in the meal (computed by the caller);
// tapping one adds a normal meal row for it and dismisses. Styled
// to match the rest of the Meal page (plain list, blueYellow
// accents, brand-style secondary subtext on the category).
// ============================================================
struct AddFoodToMealSheet: View {

    @Environment(\.presentationMode) private var presentationMode

    let foods: [Food]
    let onPick: (String) -> Void

    // Names tapped (green) but not yet committed. Done adds them all;
    // dismissing without Done discards the selection.
    @State private var selected: Set<String> = []

    var body: some View {
        NavigationView {
            Group {
                if foods.isEmpty {
                    Text("Every active Food is already in the meal.")
                      .font(.callout)
                      .foregroundColor(Color.theme.blackWhiteSecondary)
                      .multilineTextAlignment(.center)
                      .padding()
                      .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(foods) { food in
                            HStack(spacing: 8) {
                                Text(food.name)
                                  .font(.callout)
                                  .foregroundColor(selected.contains(food.name)
                                                   ? Color.theme.green
                                                   : Color.theme.blackWhite)
                                Spacer(minLength: 0)
                                Text(food.type.label)
                                  .font(.caption2)
                                  .foregroundColor(Color.theme.blackWhiteSecondary)
                            }
                              .frame(height: 28)
                              .contentShape(Rectangle())
                              .onTapGesture {
                                  if selected.contains(food.name) {
                                      selected.remove(food.name)
                                  } else {
                                      selected.insert(food.name)
                                  }
                              }
                        }
                          .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                    }
                      .listStyle(.plain)
                }
            }
              .navigationTitle("Add to Meal")
              .navigationBarTitleDisplayMode(.inline)
              .toolbar {
                  ToolbarItem(placement: .cancellationAction) {
                      Button("Done") {
                          // Add every green-selected Food, in the
                          // sheet's display order, then go back.
                          for food in foods where selected.contains(food.name) {
                              onPick(food.name)
                          }
                          presentationMode.wrappedValue.dismiss()
                      }
                        .foregroundColor(Color.theme.blueYellow)
                  }
              }
        }
    }
}
