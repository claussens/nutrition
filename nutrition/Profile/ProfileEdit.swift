import SwiftUI

struct ProfileEdit: View {

    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var profileMgr: ProfileMgr
    @Binding var tab: String

    // Local editing draft. Every row below binds to this copy, NOT
    // to profileMgr.profile — so keystrokes stay in the view and
    // nothing touches the manager (or disk) until Save. Cancel just
    // throws the draft away. The placeholder value is replaced by
    // the real active profile in onAppear (fires on every tab
    // selection) and whenever the active profile switches.
    @State private var draft = Profile(
        dateOfBirth: Date(), gender: .male, height: 0,
        bodyMassFromHealthKit: false, bodyMass: 0,
        bodyFatPercentageFromHealthKit: false, bodyFatPercentage: 0,
        activeCaloriesBurned: 0, proteinRatio: 0,
        calorieDeficit: 0, netCarbsMaximum: 0)


    var body: some View {
        Form {
            Section(header: Text("Scanner")) {
                // Moved here from the Prep page toolbar. The Anthropic
                // API key lives in the Keychain (app-global, not tied
                // to any screen), so relocating this entry point does
                // not affect a previously-entered key — it's the same
                // SettingsView reading the same Keychain item.
                NavigationLink("Scanner Settings", destination: SettingsView())
                NavigationLink("Verify All Ingredients", destination: VerifyAllWalkthrough())
            }
            // Profile switcher. Switching re-points the manager's
            // active id; the onChange below re-snapshots the draft so
            // the Base/Daily/Derived sections reflect the new profile
            // (in-flight edits to the old one are discarded).
            Section(header: Text("Profile")) {
                Picker("Active", selection: Binding(
                    get: { profileMgr.profile.id },
                    set: { profileMgr.switchToProfile($0) })) {
                    ForEach(profileMgr.profiles) { p in
                        Text(p.name.isEmpty ? "(unnamed)" : p.name).tag(p.id)
                    }
                }
                NameValue("Name", $draft.name, edit: true)
                Button(action: { profileMgr.addProfile() }) {
                    Label("Add Profile", systemImage: "plus.circle")
                }
                  .foregroundColor(Color.theme.blueYellow)
            }
            Section(header: Text("Base")) {
                NameValue("Date of Birth", $draft.dateOfBirth, control: .date)
                NameValue("Gender", $draft.gender, options: Gender.allCases, control: .picker)
                NameValue("Height", $draft.height, .inch, edit: true)
                // Macro Mode — picker selects the algorithm; chevron
                // opens the research-backed explanation page.
                NameValue("Macro Mode", description: "algorithm driving daily protein/carb/fat goals",
                          $draft.macroMode,
                          options: MacroMode.allCases, control: .picker)
                NavigationLink(destination: MacroModeDetail(profile: draft)) {
                    HStack {
                        Text("About macro modes")
                          .font(.callout)
                        Spacer()
                        Text(draft.macroMode.label)
                          .font(.caption)
                          .foregroundColor(Color.theme.blackWhiteSecondary)
                    }
                }
                // Net Carbs Maximum is the editable ceiling in .keto;
                // in ratio modes the carb grams are derived, so we
                // show a read-only target row instead.
                if draft.macroMode == .keto {
                    NameValue("Net Carbs Maximum", description: "daily consumption maximum (carbs - fiber)", $draft.netCarbsMaximum, edit: true)
                } else {
                    NameValue("Net Carbs Target", description: "computed from macro mode (cals × carbs%)",
                              .constant(draft.effectiveNetCarbsMaximum))
                }
                NameValue("Protein Ratio", description: "daily protein grams required / lb of lean body mass (floor in ratio modes)", $draft.proteinRatio, precision: 2, edit: true)
                NameValue("Caloric Deficit", description: "percentage to adjust daily caloric and macro goals", $draft.calorieDeficit, .percentage, edit: true)
            }
            Section(header: Text("Daily Metrics")) {
                NameValue("Weight from Health App", description: "source daily weight updates from apple health app", $draft.bodyMassFromHealthKit, control: .toggle)
                if !draft.bodyMassFromHealthKit {
                    NameValue("Weight", description: "body mass", $draft.bodyMass, .pound, precision: 1, edit: true)
                }
                NameValue("Body Fat % from Health App", description: "source daily body fat % updates from apple health app", $draft.bodyFatPercentageFromHealthKit, control: .toggle)
                if !draft.bodyFatPercentageFromHealthKit {
                    NameValue("Body Fat %", description: "from apple health app", $draft.bodyFatPercentage, .percentage, precision: 1, edit: true)
                }
            }
            Section(header: Text("Derived Profile Data")) {
                NavigationLink("Vitamins and Minerals", destination: VitaminMineralList())
                NameValue("Age", $draft.age, .year, precision: 1)
                NameValue("Weight", description: "body mass (from health app)", $draft.bodyMassKg, .kilogram)
                NameValue("Height", $draft.heightCm, .centimeter)
                NameValue("Body Mass Index", description: "normal <25, fat >25, obese >30", $draft.bodyMassIndex, precision: 1)
                NameValue("Lean Body Mass", description: "non-fat body mass", $draft.leanBodyMass, .pound)
                NameValue("Fat Mass", description: "weight * body fat percentage", $draft.fatMass, .pound)
                NameValue("Water", description: "daily consumption minimum, weight/2 * ~.03", $draft.waterLiters, .liter, precision: 1)

            }
            Section(header: Text("Gross (without the caloric deficit)")) {
                Group {
                    NavigationLink(destination: ProfileMetricDetail(metric: .baseMetabolicRate, profile: draft)) {
                        NameValue("Base Metabolic Rate", description: "Mifflin-St Jeor", $draft.caloriesBaseMetabolicRate, .calorie)
                    }
                    NavigationLink(destination: ProfileMetricDetail(metric: .restingCalories, profile: draft)) {
                        NameValue("Resting Calories", description: "Mifflin-St Jeor BMR * 1.2", $draft.caloriesResting, .calorie)
                    }
                    NavigationLink(destination: ProfileMetricDetail(metric: .activeCaloriesBurned, profile: draft)) {
                        NameValue("Active Calories Burned", description: "daily calories burned due to exercise/movement", $draft.activeCaloriesBurned, .calorie)
                    }
                    NavigationLink(destination: ProfileMetricDetail(metric: .unadjustedCaloricGoal, profile: draft)) {
                        NameValue("Unadjusted Caloric Goal", description: "resting + active energy burned", $draft.caloriesGoalUnadjusted, .calorie)
                    }
                    NavigationLink(destination: ProfileMetricDetail(metric: .fatGoalGross, profile: draft)) {
                        NameValue("Fat Goal", description: "caloric goal - netCarbs - protein", $draft.fatGoalUnadjusted)
                    }
                    NavigationLink(destination: ProfileMetricDetail(metric: .fiberMinimumGross, profile: draft)) {
                        NameValue("Fiber Minimum", description: "14g fiber/1k consumed calories", $draft.fiberMinimumUnadjusted)
                    }
                    NavigationLink(destination: ProfileMetricDetail(metric: .netCarbsMaximum, profile: draft)) {
                        NameValue("Net Carbs Maximum", description: "consumption max (carbs - fiber)", .constant(draft.effectiveNetCarbsMaximumUnadjusted))
                    }
                    NavigationLink(destination: ProfileMetricDetail(metric: .proteinGoal, profile: draft)) {
                        NameValue("Protein Goal", description: "lean body mass * protein ratio", $draft.proteinGoalUnadjusted)
                    }
                    NavigationLink(destination: ProfileMetricDetail(metric: .fatPercentGross, profile: draft)) {
                        NameValue("Fat %", description: "percentage of calories from fat", $draft.fatGoalPercentageUnadjusted, .percentage)
                    }
                    NavigationLink(destination: ProfileMetricDetail(metric: .netCarbsPercentGross, profile: draft)) {
                        NameValue("Net Carbs %", description: "percentage of calories from carbs", $draft.netCarbsMaximumPercentageUnadjusted, .percentage)
                    }
                }
                NavigationLink(destination: ProfileMetricDetail(metric: .proteinPercentGross, profile: draft)) {
                    NameValue("Protein %", description: "percentage of calories from protein", $draft.proteinGoalPercentageUnadjusted, .percentage)
                }
            }
            Section(header: Text("Net (with the caloric deficit)")) {
                NavigationLink(destination: ProfileMetricDetail(metric: .unadjustedCaloricGoal, profile: draft)) {
                    NameValue("Unadjusted Caloric Goal", description: "gross caloric goal", $draft.caloriesGoalUnadjusted, .calorie)
                }
                NavigationLink(destination: ProfileMetricDetail(metric: .caloricDeficit, profile: draft)) {
                    NameValue("Caloric Deficit", description: "adjustment to daily gross caloric goal", $draft.calorieDeficit, .percentage)
                }
                NavigationLink(destination: ProfileMetricDetail(metric: .netCaloricGoal, profile: draft)) {
                    NameValue("Net Caloric Goal", description: "with calorie deficit applied", $draft.caloriesGoal, .calorie)
                }
                NavigationLink(destination: ProfileMetricDetail(metric: .fatGoalNet, profile: draft)) {
                    NameValue("Fat Goal", description: "net caloric goal - netCarbs - protein", $draft.fatGoal)
                }
                NavigationLink(destination: ProfileMetricDetail(metric: .fiberMinimumNet, profile: draft)) {
                    NameValue("Fiber Minimum", description: "14g fiber/1000 consumed cal", $draft.fiberMinimum)
                }
                NavigationLink(destination: ProfileMetricDetail(metric: .netCarbsMaximum, profile: draft)) {
                    NameValue("Net Carbs Maximum", description: "consumption max (carbs - fiber)", .constant(draft.effectiveNetCarbsMaximum))
                }
                NavigationLink(destination: ProfileMetricDetail(metric: .proteinGoal, profile: draft)) {
                    NameValue("Protein Goal", description: "lean body mass * protein ratio", $draft.proteinGoal)
                }
                NavigationLink(destination: ProfileMetricDetail(metric: .fatPercentNet, profile: draft)) {
                    NameValue("Fat %", description: "percentage of net calories from fat", $draft.fatGoalPercentage, .percentage)
                }
                NavigationLink(destination: ProfileMetricDetail(metric: .netCarbsPercentNet, profile: draft)) {
                    NameValue("Net Carbs %", description: "percentage of net calories from carbs", $draft.netCarbsMaximumPercentage, .percentage)
                }
                NavigationLink(destination: ProfileMetricDetail(metric: .proteinPercentNet, profile: draft)) {
                    NameValue("Protein %", description: "percentage of net calories from protein", $draft.proteinGoalPercentage, .percentage)
                }
            }
        }
        // .environment(\.defaultMinListRowHeight, 60)
        // .environment(\.defaultMinListHeaderHeight, 45)
          .padding([.leading, .trailing], -20)
          // Snapshot the active profile into the draft whenever the
          // page appears (TabView re-fires onAppear on each tab
          // selection) and whenever the active profile changes
          // (switcher picker / Add Profile) — the new profile's
          // values replace any in-flight edits to the old one.
          .onAppear { draft = profileMgr.profile }
          .onChange(of: profileMgr.activeProfileId) { _ in
              draft = profileMgr.profile
          }
          .navigationBarBackButtonHidden(true)
          .toolbar {
              ToolbarItem(placement: .navigation) {
                  Button("Cancel", action: cancel)
                    .foregroundColor(Color.theme.blueYellow)
              }
              ToolbarItem(placement: .primaryAction) {
                  Button("Save", action: save)
                    .foregroundColor(Color.theme.blueYellow)
              }
              ToolbarItemGroup(placement: .keyboard) {
                  HStack {
                      DismissKeyboard()
                      Spacer()
                      Button("Save", action: save)
                        .foregroundColor(Color.theme.blueYellow)
                  }
              }
          }
    }


    // Cancel = discard the draft. Nothing was written to the manager
    // while editing, so there is nothing to roll back — just re-sync
    // the draft (in case the tab reappears without onAppear) and go.
    func cancel() {
        withAnimation {
            draft = profileMgr.profile
            tab = "Meal"
        }
    }


    // Save = the single commit point: splice the draft into the
    // manager (persists via ProfileMgr's didSet) and flush.
    func save() {
        withAnimation {
            profileMgr.profile = draft
            profileMgr.serialize()
            tab = "Meal"
        }
    }
}


// =============================================================
// ProfileMetricDetail — chevron-driven inline documentation for
// the derived rows in the Gross and Net sections of ProfileEdit.
// Each row pushes a detail page explaining what the value is,
// how it's derived (formula + live inputs from the profile),
// and any notes worth knowing.
// =============================================================

enum ProfileMetric {
    case baseMetabolicRate
    case restingCalories
    case activeCaloriesBurned
    case unadjustedCaloricGoal
    case caloricDeficit
    case netCaloricGoal
    case fatGoalGross
    case fatGoalNet
    case fiberMinimumGross
    case fiberMinimumNet
    case netCarbsMaximum
    case proteinGoal           // identical formula in gross + net (depends on body comp, not calories)
    case fatPercentGross
    case fatPercentNet
    case netCarbsPercentGross
    case netCarbsPercentNet
    case proteinPercentGross
    case proteinPercentNet
}


struct ProfileMetricDoc {
    let title: String
    let result: String                                     // "1,856 cals"
    let what: String                                       // plain-English summary
    let formula: String                                    // math notation, monospaced
    let inputs: [(label: String, value: String)]
    let notes: String?
}


struct ProfileMetricDetail: View {

    let metric: ProfileMetric
    let profile: Profile

    var body: some View {
        let doc = profileMetricDoc(metric, profile: profile)
        Form {
            Section("Value") {
                HStack {
                    Text("Current")
                      .font(.callout)
                    Spacer()
                    Text(doc.result)
                      .font(.body.monospacedDigit())
                      .foregroundColor(Color.theme.blueYellow)
                }
            }

            Section("What it is") {
                Text(doc.what)
                  .font(.callout)
            }

            Section("Formula") {
                Text(doc.formula)
                  .font(.callout.monospaced())
            }

            if !doc.inputs.isEmpty {
                Section("Current inputs") {
                    ForEach(doc.inputs.indices, id: \.self) { i in
                        HStack {
                            Text(doc.inputs[i].label)
                              .font(.callout)
                            Spacer()
                            Text(doc.inputs[i].value)
                              .font(.body.monospacedDigit())
                              .foregroundColor(Color.theme.blackWhiteSecondary)
                        }
                    }
                }
            }

            if let notes = doc.notes {
                Section("Notes") {
                    Text(notes)
                      .font(.caption)
                }
            }
        }
          .navigationTitle(doc.title)
          .navigationBarTitleDisplayMode(.inline)
    }
}


// Helper: format a Double with units. The integer-cal/g/% style
// matches what the rows render via NameValue's default precision.
private func cals(_ v: Double) -> String { "\(v.formattedString(0)) cals" }
private func grams(_ v: Double) -> String { "\(v.formattedString(0)) g" }
private func pct(_ v: Double)  -> String { "\(v.formattedString(0))%" }


func profileMetricDoc(_ metric: ProfileMetric, profile: Profile) -> ProfileMetricDoc {

    switch metric {

    case .baseMetabolicRate:
        return ProfileMetricDoc(
          title: "Base Metabolic Rate",
          result: cals(profile.caloriesBaseMetabolicRate),
          what: "Calories your body burns at complete rest — what it takes to keep your organs running. Doesn't include any movement, digestion, or exercise.",
          formula: profile.gender == .male
            ? "Mifflin-St Jeor (male):\n  9.99·weight(kg)\n+ 6.25·height(cm)\n− 4.92·age\n+ 5"
            : "Mifflin-St Jeor (female):\n  9.99·weight(kg)\n+ 6.25·height(cm)\n− 4.92·age\n− 161",
          inputs: [
            ("weight",  "\(profile.bodyMassKg.formattedString(1)) kg"),
            ("height",  "\(profile.heightCm.formattedString(1)) cm"),
            ("age",     "\(profile.age.formattedString(1)) yrs"),
            ("gender",  profile.gender.formattedString(0)),
          ],
          notes: "Mifflin-St Jeor is the modern replacement for Harris-Benedict; ~5% more accurate in non-athletes. Female formula's −161 is conventional; ours uses 4.92·age (Mifflin's published coefficient) rather than the rounded 5."
        )

    case .restingCalories:
        return ProfileMetricDoc(
          title: "Resting Calories",
          result: cals(profile.caloriesResting),
          what: "Calories you'd burn across a sedentary day — BMR plus the energy used by light activity (sitting, eating, fidgeting). Does NOT include intentional exercise.",
          formula: "BMR · 1.2",
          inputs: [
            ("BMR",                 cals(profile.caloriesBaseMetabolicRate)),
            ("activity multiplier", "1.2 (sedentary)"),
          ],
          notes: "The 1.2 factor is the standard Harris-Benedict 'sedentary' multiplier. Active Calories Burned is tracked separately so this stays stable."
        )

    case .activeCaloriesBurned:
        return ProfileMetricDoc(
          title: "Active Calories Burned",
          result: cals(profile.activeCaloriesBurned),
          what: "Calories you burn on top of resting through exercise and intentional movement. A stored value — update it when your activity meaningfully changes.",
          formula: "Stored value (you set it on Profile)",
          inputs: [],
          notes: "Day-to-day fluctuations don't matter. Treat this as a weekly average for the kind of activity you actually do. HealthKit integration is a TODO."
        )

    case .unadjustedCaloricGoal:
        return ProfileMetricDoc(
          title: "Unadjusted Caloric Goal",
          result: cals(profile.caloriesGoalUnadjusted),
          what: "Total daily calories before the deficit is applied. This is what you'd eat to maintain your current weight given your activity.",
          formula: "Resting Calories + Active Calories Burned",
          inputs: [
            ("resting", cals(profile.caloriesResting)),
            ("active",  cals(profile.activeCaloriesBurned)),
          ],
          notes: nil
        )

    case .caloricDeficit:
        return ProfileMetricDoc(
          title: "Caloric Deficit",
          result: "\(profile.calorieDeficit)%",
          what: "Percentage cut applied to the gross caloric goal to drive weight loss. Higher = faster loss but harder to sustain and more lean-mass risk.",
          formula: "Stored value (you set it on Profile)",
          inputs: [],
          notes: "10–15% is mild, 20% is moderate, >25% is aggressive. Protein and net-carb floors stay fixed across the cut to protect muscle and stay below carb tolerance."
        )

    case .netCaloricGoal:
        return ProfileMetricDoc(
          title: "Net Caloric Goal",
          result: cals(profile.caloriesGoal),
          what: "Your actual daily calorie target after applying the deficit. This is the number you eat to.",
          formula: "Unadjusted Caloric Goal · (1 − Deficit%)",
          inputs: [
            ("unadjusted goal", cals(profile.caloriesGoalUnadjusted)),
            ("deficit",         "\(profile.calorieDeficit)%"),
          ],
          notes: nil
        )

    case .fatGoalGross:
        if let s = profile.macroMode.split {
            return ProfileMetricDoc(
              title: "Fat Goal (Gross)",
              result: grams(profile.fatGoalUnadjusted),
              what: "Grams of fat per day at the gross caloric goal. In '\(profile.macroMode.label)' mode fat is a fixed percentage of calories (the preset).",
              formula: "Caloric Goal × Fat% / 9",
              inputs: [
                ("caloric goal", cals(profile.caloriesGoalUnadjusted)),
                ("fat %",        "\(Int(s.fat))%"),
              ],
              notes: "Fat is 9 cal/g. The preset's protein/carbs/fat % is the source of truth for the split; LBM × ProteinRatio still acts as a protein FLOOR (the larger of the two wins for protein)."
            )
        }
        return ProfileMetricDoc(
          title: "Fat Goal (Gross)",
          result: grams(profile.fatGoalUnadjusted),
          what: "Grams of fat per day at the gross (no-deficit) caloric goal. Computed as whatever's left after protein and net-carbs are subtracted.",
          formula: "(Caloric Goal − (Protein·4 + NetCarbs·4)) / 9",
          inputs: [
            ("caloric goal", cals(profile.caloriesGoalUnadjusted)),
            ("protein",      grams(profile.proteinGoalUnadjusted)),
            ("net carbs",    grams(profile.effectiveNetCarbsMaximumUnadjusted)),
          ],
          notes: "Fat is 9 cal/g; protein and net-carbs are 4 cal/g. On keto, fat is the elastic macro — it absorbs whatever caloric room is left."
        )

    case .fatGoalNet:
        if let s = profile.macroMode.split {
            return ProfileMetricDoc(
              title: "Fat Goal (Net)",
              result: grams(profile.fatGoal),
              what: "Grams of fat per day at the net (after-deficit) caloric goal. In '\(profile.macroMode.label)' mode fat is a fixed percentage of net calories.",
              formula: "Net Caloric Goal × Fat% / 9",
              inputs: [
                ("net caloric goal", cals(profile.caloriesGoal)),
                ("fat %",            "\(Int(s.fat))%"),
              ],
              notes: "Fat is 9 cal/g. With a caloric deficit applied, the preset % is held constant against the smaller net goal — protein floor still wins if larger."
            )
        }
        return ProfileMetricDoc(
          title: "Fat Goal (Net)",
          result: grams(profile.fatGoal),
          what: "Grams of fat per day at the net (after-deficit) caloric goal. This is your actual daily fat target.",
          formula: "(Net Caloric Goal − (Protein·4 + NetCarbs·4)) / 9",
          inputs: [
            ("net caloric goal", cals(profile.caloriesGoal)),
            ("protein",          grams(profile.proteinGoal)),
            ("net carbs",        grams(profile.effectiveNetCarbsMaximum)),
          ],
          notes: "Fat absorbs the deficit. Protein and net-carb caps stay the same regardless of how aggressive the deficit is."
        )

    case .fiberMinimumGross:
        return ProfileMetricDoc(
          title: "Fiber Minimum (Gross)",
          result: grams(profile.fiberMinimumUnadjusted),
          what: "Daily fiber target scaled to the gross caloric goal — 14 grams per 1,000 calories. A standard digestive-health rule of thumb.",
          formula: "(Caloric Goal / 1000) · 14",
          inputs: [
            ("caloric goal", cals(profile.caloriesGoalUnadjusted)),
          ],
          notes: "Source: USDA / Dietary Guidelines for Americans. Floor only — going over is fine."
        )

    case .fiberMinimumNet:
        return ProfileMetricDoc(
          title: "Fiber Minimum (Net)",
          result: grams(profile.fiberMinimum),
          what: "Daily fiber target scaled to the net caloric goal. The number you actually aim for since you're eating to the net goal.",
          formula: "(Net Caloric Goal / 1000) · 14",
          inputs: [
            ("net caloric goal", cals(profile.caloriesGoal)),
          ],
          notes: "Same 14g/1000kcal rule. The smaller denominator gives a lower floor than the gross version."
        )

    case .netCarbsMaximum:
        if let s = profile.macroMode.split {
            return ProfileMetricDoc(
              title: "Net Carbs Target",
              result: grams(profile.effectiveNetCarbsMaximum),
              what: "Daily carb target in '\(profile.macroMode.label)' mode. Derived from the caloric goal and the preset carbs % (whatever's left after protein + fat absorb their pieces).",
              formula: "(Net Caloric Goal − Protein·4 − Fat·9) / 4",
              inputs: [
                ("net caloric goal", cals(profile.caloriesGoal)),
                ("protein",          grams(profile.proteinGoal)),
                ("fat",              grams(profile.fatGoal)),
                ("preset carbs %",   "\(Int(s.carbs))%"),
              ],
              notes: "In ratio modes this is a target, not a ceiling. Going over occasionally is fine on a non-keto plan; the preset is the day's structure, not a hard line."
            )
        }
        return ProfileMetricDoc(
          title: "Net Carbs Maximum",
          result: grams(profile.netCarbsMaximum),
          what: "Daily ceiling on net carbs (total carbs − fiber). Stored manually on the Base section. The same value applies in both gross and net since it's not derived from the caloric goal.",
          formula: "Stored value (you set it on Profile)",
          inputs: [],
          notes: "20g is the standard ketogenic threshold. Lower for stricter ketosis (15g) or carnivore (close to 0). Going over kicks you out of ketosis."
        )

    case .proteinGoal:
        if let s = profile.macroMode.split {
            let lbmFloor = profile.leanBodyMass * profile.proteinRatio
            let presetProtein = profile.caloriesGoalUnadjusted * s.protein / 100 / 4
            let chosen = lbmFloor >= presetProtein ? "LBM floor wins" : "preset % wins"
            return ProfileMetricDoc(
              title: "Protein Goal",
              result: grams(profile.proteinGoalUnadjusted),
              what: "Daily protein target. In '\(profile.macroMode.label)' mode, the larger of LBM × ratio (floor) and Caloric Goal × Protein% wins — \(chosen).",
              formula: "max( Lean Body Mass · Protein Ratio , Caloric Goal · Protein% / 4 )",
              inputs: [
                ("lean body mass", "\(profile.leanBodyMass.formattedString(1)) lb"),
                ("protein ratio",  "\(profile.proteinRatio.formattedString(2)) g/lb LBM"),
                ("LBM floor",      grams(lbmFloor)),
                ("preset protein %", "\(Int(s.protein))%"),
                ("preset grams",   grams(presetProtein)),
              ],
              notes: "Range: 0.8–1.2 g/lb LBM. Higher for muscle-building or older adults guarding against sarcopenia; lower for sedentary or very lean. The LBM floor stays in force across all modes — it's the protein safety net for growth and recovery."
            )
        }
        return ProfileMetricDoc(
          title: "Protein Goal",
          result: grams(profile.proteinGoalUnadjusted),
          what: "Daily protein target. Depends on body composition rather than caloric goal, so the same value applies in both gross and net.",
          formula: "Lean Body Mass · Protein Ratio",
          inputs: [
            ("lean body mass", "\(profile.leanBodyMass.formattedString(1)) lb"),
            ("protein ratio",  "\(profile.proteinRatio.formattedString(2)) g/lb LBM"),
          ],
          notes: "Range: 0.8–1.2 g/lb LBM. Higher for muscle-building or older adults guarding against sarcopenia; lower for sedentary or very lean. Protein stays fixed across the caloric deficit to protect muscle."
        )

    case .fatPercentGross:
        return ProfileMetricDoc(
          title: "Fat % (Gross)",
          result: pct(profile.fatGoalPercentageUnadjusted),
          what: "Share of gross calories coming from fat. On keto this is the dominant macro by calories.",
          formula: "(Fat Goal · 9) / Caloric Goal · 100",
          inputs: [
            ("fat goal",     grams(profile.fatGoalUnadjusted)),
            ("caloric goal", cals(profile.caloriesGoalUnadjusted)),
          ],
          notes: "Typical keto split is 70–75% fat. Lower means you're flirting with the protein-as-glucose threshold."
        )

    case .fatPercentNet:
        return ProfileMetricDoc(
          title: "Fat % (Net)",
          result: pct(profile.fatGoalPercentage),
          what: "Share of net (after-deficit) calories coming from fat. Drops as the deficit gets larger — fat takes the cut while protein and carbs hold steady.",
          formula: "(Fat Goal · 9) / Net Caloric Goal · 100",
          inputs: [
            ("fat goal",         grams(profile.fatGoal)),
            ("net caloric goal", cals(profile.caloriesGoal)),
          ],
          notes: nil
        )

    case .netCarbsPercentGross:
        return ProfileMetricDoc(
          title: "Net Carbs % (Gross)",
          result: pct(profile.netCarbsMaximumPercentageUnadjusted),
          what: "Share of gross calories coming from net carbs. Should be small on keto — a single-digit number.",
          formula: "(Net Carbs · 4) / Caloric Goal · 100",
          inputs: [
            ("net carbs",    grams(profile.effectiveNetCarbsMaximumUnadjusted)),
            ("caloric goal", cals(profile.caloriesGoalUnadjusted)),
          ],
          notes: nil
        )

    case .netCarbsPercentNet:
        return ProfileMetricDoc(
          title: "Net Carbs % (Net)",
          result: pct(profile.netCarbsMaximumPercentage),
          what: "Share of net (after-deficit) calories coming from net carbs.",
          formula: "(Net Carbs · 4) / Net Caloric Goal · 100",
          inputs: [
            ("net carbs",        grams(profile.effectiveNetCarbsMaximum)),
            ("net caloric goal", cals(profile.caloriesGoal)),
          ],
          notes: "Same gram cap, smaller denominator — this percentage rises slightly with deeper deficits."
        )

    case .proteinPercentGross:
        return ProfileMetricDoc(
          title: "Protein % (Gross)",
          result: pct(profile.proteinGoalPercentageUnadjusted),
          what: "Share of gross calories coming from protein.",
          formula: "(Protein · 4) / Caloric Goal · 100",
          inputs: [
            ("protein",      grams(profile.proteinGoalUnadjusted)),
            ("caloric goal", cals(profile.caloriesGoalUnadjusted)),
          ],
          notes: nil
        )

    case .proteinPercentNet:
        return ProfileMetricDoc(
          title: "Protein % (Net)",
          result: pct(profile.proteinGoalPercentage),
          what: "Share of net (after-deficit) calories coming from protein. Rises as the deficit grows since protein grams stay fixed while total calories shrink.",
          formula: "(Protein · 4) / Net Caloric Goal · 100",
          inputs: [
            ("protein",          grams(profile.proteinGoal)),
            ("net caloric goal", cals(profile.caloriesGoal)),
          ],
          notes: "A rising protein-% during a cut is by design — it's the muscle-protective effect of holding protein constant while cutting calories."
        )
    }
}


// =============================================================
// MacroModeDetail — opened from the chevron on the Base section's
// "About macro modes" row. Comprehensive reference for the five
// modes: what they are, when to pick them, research basis, and a
// live preview of what the active profile looks like under each.
//
// The page also addresses the protein-basis confusion (g/lb LBM vs
// g/kg BW vs g/lb BW vs % cals) by showing all four equivalents
// computed against the active profile.
// =============================================================
struct MacroModeDetail: View {

    let profile: Profile


    var body: some View {
        Form {
            Section("Active mode") {
                HStack {
                    Text(profile.macroMode.label)
                      .font(.callout)
                    Spacer()
                    if let s = profile.macroMode.split {
                        Text("\(Int(s.protein)) / \(Int(s.carbs)) / \(Int(s.fat))")
                          .font(.body.monospacedDigit())
                          .foregroundColor(Color.theme.blueYellow)
                    } else {
                        Text("carb-ceiling")
                          .font(.body.monospacedDigit())
                          .foregroundColor(Color.theme.blueYellow)
                    }
                }
                Text("(P / C / F %)")
                  .font(.caption)
                  .foregroundColor(Color.theme.blackWhiteSecondary)
            }

            Section("Today's numbers for \(profile.name)") {
                rowG("Caloric goal (net)",  cals(profile.caloriesGoal))
                rowG("Protein",             "\(grams(profile.proteinGoal)) (\(Int(profile.proteinGoalPercentage))%)")
                rowG("Carbs",               "\(grams(profile.effectiveNetCarbsMaximum)) (\(Int(profile.netCarbsMaximumPercentage))%)")
                rowG("Fat",                 "\(grams(profile.fatGoal)) (\(Int(profile.fatGoalPercentage))%)")
            }

            Section("The five modes") {
                modeRow(.keto,
                        "Carb-ceiling algorithm. Protein from LBM × ratio; netCarbs is a hard daily ceiling; fat absorbs the rest. The original keto math.",
                        "20g net carbs is the standard threshold; lower for stricter ketosis. Fat ends up dominant (~70–75% of calories) by arithmetic, not by design.")
                modeRow(.lowCarb,
                        "Atkins-maintenance feel. Moderate fat, low-but-real carbs, somewhat-elevated protein. Useful as a step-down from keto.",
                        "Inside the AMDR fat band (25–35%) only at the upper end. Sustainable for adults; not ideal for high-volume training or growing kids.")
                modeRow(.mediterranean,
                        "Heart-health gold standard: lean protein, plenty of produce + whole grains, olive oil & nuts for fat. Most-studied long-term diet for cardiovascular outcomes.",
                        "Sits at the top of the AMDR fat band. Family-friendly and sustainable; slightly fat-heavier than performance-optimal for daily-training kids.")
                modeRow(.balanced,
                        "USDA / AMDR midpoint — the official 'default-healthy' for adolescents and active adults. Strong carb base for glycogen, fat above the 25% floor.",
                        "Best general-purpose pick for an active adolescent. Inside every relevant guideline envelope (IOM AMDR, ACSM, AAP).")
                modeRow(.athlete,
                        "Endurance/team-sport split — glycogen-heavy carbs, protein for recovery, fat at the floor of the safe band.",
                        "Pick for high training volume. Don't go lower on fat (20% is the adolescent floor — below risks hormones, fat-soluble vitamin absorption, RED-S).")
            }

            Section("Protein ratio — same number, four units") {
                Text("LBM × ProteinRatio is the source of truth in this app; the equivalents below let you cross-reference with whatever convention you're used to (clinical literature uses g/kg BW; US practice uses g/lb BW; bodybuilding uses g/lb LBM; dietary guidelines use % of cals). All four values describe the same daily protein floor for this profile.")
                  .font(.caption)
                rowG("Stored: g/lb LBM",      "\(profile.proteinRatio.formattedString(2))")
                rowG("LBM",                   "\(profile.leanBodyMass.formattedString(1)) lb")
                rowG("Daily protein floor",   grams(profile.leanBodyMass * profile.proteinRatio))
                let dailyFloor = profile.leanBodyMass * profile.proteinRatio
                rowG("= g/kg body weight",    "\((dailyFloor / profile.bodyMassKg).formattedString(2))")
                rowG("= g/lb body weight",    "\((dailyFloor / profile.bodyMass).formattedString(2))")
                rowG("= % of net calories",   "\(Int((dailyFloor * 4) / profile.caloriesGoal * 100))%")
            }

            Section("Where the numbers come from") {
                Text("• **IOM AMDR (ages 4–18):** protein 10–30%, carbs 45–65%, fat 25–35%. Official US adolescent reference.")
                  .font(.caption)
                Text("• **ACSM / IOC sports nutrition:** protein 1.2–2.0 g/kg/day for active people; carbs 5–7 g/kg/day moderate, up to 8 g/kg on heavy training days; fat ≥25% of calories.")
                  .font(.caption)
                Text("• **Adolescent floors:** fat below ~20% impairs hormone production, fat-soluble vitamin absorption, and (in athletes) risks RED-S. Treat 20% as the bottom of the safe band for a growing kid.")
                  .font(.caption)
                Text("• **The LBM-floor invariant:** in all ratio modes, LBM × ProteinRatio acts as a minimum. If the preset's protein % would give less, we take the floor. Growing/training profiles never undershoot growth protein.")
                  .font(.caption)
            }
        }
          .navigationTitle("Macro Modes")
          .navigationBarTitleDisplayMode(.inline)
    }


    @ViewBuilder
    private func rowG(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.callout)
            Spacer()
            Text(value)
              .font(.body.monospacedDigit())
              .foregroundColor(Color.theme.blackWhiteSecondary)
        }
    }


    @ViewBuilder
    private func modeRow(_ mode: MacroMode, _ what: String, _ when: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(mode.label)
                  .font(.callout)
                  .foregroundColor(mode == profile.macroMode ? Color.theme.blueYellow : Color.theme.blackWhite)
                Spacer()
                if let s = mode.split {
                    Text("\(Int(s.protein)) / \(Int(s.carbs)) / \(Int(s.fat))")
                      .font(.caption.monospacedDigit())
                      .foregroundColor(Color.theme.blackWhiteSecondary)
                } else {
                    Text("ceiling")
                      .font(.caption.monospacedDigit())
                      .foregroundColor(Color.theme.blackWhiteSecondary)
                }
            }
            Text(what).font(.caption)
            Text(when).font(.caption2).foregroundColor(Color.theme.blackWhiteSecondary)
        }
          .padding(.vertical, 2)
    }
}
