import Foundation


class ProfileMgr: ObservableObject {


    // SINGLE source of truth: the full set of profiles plus the id of
    // the active one. The array here is the source of truth for
    // persistence and lets the Profile page switch between them.
    @Published var profiles: [Profile] = [] {
        didSet { saveProfiles() }
    }


    // Id of the active profile. Published so SwiftUI re-renders when the
    // active profile is switched. Persisted to UserDefaults via didSet.
    @Published var activeProfileId: String = "" {
        didSet {
            UserDefaults.standard.set(activeProfileId, forKey: "activeProfileId")
        }
    }


    // The active profile, as a COMPUTED view over the single source of
    // truth (`profiles` + `activeProfileId`). Reads return the active
    // element; writes splice the new value back into `profiles[i]`
    // (which persists via profiles' own didSet). Edit screens bind to
    // a local @State draft and assign `profile = draft` only on Save —
    // every write through this setter hits disk, so nothing should
    // write here per-keystroke.
    var profile: Profile {
        get {
            if let p = profiles.first(where: { $0.id == activeProfileId }) {
                return p
            }
            return profiles.first ?? Profile(
                dateOfBirth: Date(), gender: .male, height: 0,
                bodyMassFromHealthKit: false, bodyMass: 0,
                bodyFatPercentageFromHealthKit: false, bodyFatPercentage: 0,
                activeCaloriesBurned: 0, proteinRatio: 0,
                calorieDeficit: 0, netCarbsMaximum: 0)
        }
        set {
            if let i = profiles.firstIndex(where: { $0.id == newValue.id }) {
                profiles[i] = newValue
            } else {
                profiles.append(newValue)
            }
            // Keep the active id pointing at the written profile (covers
            // an id change made through this setter).
            if activeProfileId != newValue.id {
                activeProfileId = newValue.id
            }
        }
    }


    init() {
        // 1. New schema: array of profiles + active id.
        if let arr = Self.loadProfiles(), !arr.isEmpty {
            self.profiles = arr
            let activeId = UserDefaults.standard.string(forKey: "activeProfileId")
            self.activeProfileId = arr.first(where: { $0.id == activeId })?.id ?? arr[0].id
        }
        // 2. Migrate from the old single-profile schema (key "profile").
        // The custom Profile.init(from:) handles the missing id/name.
        else if var migrated = UserDefaultsStore<Profile>(key: "profile").load() {
            if migrated.id.isEmpty { migrated.id = UUID().uuidString }
            if migrated.name.isEmpty { migrated.name = "Shane" }
            self.profiles = [migrated]
            self.activeProfileId = migrated.id
            UserDefaults.standard.set(migrated.id, forKey: "activeProfileId")
        }
        // 3. Fresh install — seed Shane's default profile.
        else {
            print("...creating initial default profile")
            var components = DateComponents()
            components.year = 1967
            components.month = 9
            components.day = 27
            let seed = Profile(
                name: "Shane",
                dateOfBirth: Calendar.current.date(from: components)!,
                gender: .male, height: 72,
                bodyMassFromHealthKit: true, bodyMass: 222,
                bodyFatPercentageFromHealthKit: true, bodyFatPercentage: 20,
                activeCaloriesBurned: 600,
                proteinRatio: 1.2, calorieDeficit: 20, netCarbsMaximum: 20)
            self.profiles = [seed]
            self.activeProfileId = seed.id
            UserDefaults.standard.set(seed.id, forKey: "activeProfileId")
        }

        // One-time backfill: add Caden's profile to existing single-
        // profile installs (fresh installs would also receive him via
        // this path; the flag stops us re-adding after a rename/delete).
        let backfillKey = "didSeedSecondaryProfile.caden"
        if !UserDefaults.standard.bool(forKey: backfillKey) {
            if !profiles.contains(where: { $0.name == "Caden" }) {
                profiles.append(Self.cadenSeed())
            }
            UserDefaults.standard.set(true, forKey: backfillKey)
        }

        // One-shot fix-up for existing data: rename the previously-
        // seeded "Caden Claussen" -> "Caden" and bump bodyMass from
        // the placeholder 120 -> 129. Idempotent via the flag so a
        // later user-driven rename/reweigh isn't bulldozed.
        let cadenFixupKey = "didFixupCaden.nameAndWeight.v1"
        if !UserDefaults.standard.bool(forKey: cadenFixupKey) {
            UserDefaults.standard.set(true, forKey: cadenFixupKey)
            if let i = profiles.firstIndex(where: { $0.name == "Caden Claussen" }) {
                profiles[i].name = "Caden"
                if profiles[i].bodyMass == 120 { profiles[i].bodyMass = 129 }
                if profile.id == profiles[i].id { profile = profiles[i] }
            }
        }

        // One-shot fix-up for the early-refactor data leak: the
        // per-profile data refactor (commit 3d0ecd0) landed BEFORE
        // the profileName-aware default-meal seeding (commit 9b8bb3e),
        // so Caden's empty meal got seeded with Shane's defaults under
        // his per-profile key. Clear those keys for Caden so the next
        // reload re-seeds via the new switch-on-profileName branch.
        // Flag-gated: cannot bulldoze later edits.
        let reseedKey = "didReseedCadenStaleSeedData.v1"
        if !UserDefaults.standard.bool(forKey: reseedKey) {
            UserDefaults.standard.set(true, forKey: reseedKey)
            if let caden = profiles.first(where: { $0.name == "Caden" }) {
                let id = caden.id
                for key in [
                    "mealIngredient.\(id)",
                    "mealIngredient.migrated.\(id)",
                    "adjustment.\(id)",
                    "adjustment.migrated.\(id)",
                    "foodComposite.\(id)",
                    "foodComposite.migrated.\(id)",
                ] {
                    UserDefaults.standard.removeObject(forKey: key)
                }
            }
        }
    }


    private static func cadenSeed() -> Profile {
        var c = DateComponents()
        c.year = 2012; c.month = 6; c.day = 16
        // Caden Claussen — daily basketball + daily lifting, growing
        // athlete. Body fat estimated (12% ≈ "pretty low" athletic
        // teen); fine-tune in the Profile page. 0% caloric deficit
        // (no cutting on a growing kid). netCarbsMaximum (325g) is
        // used by the model as the carb-grams TARGET, not a ceiling
        // — picks ~50% carbs of the unadjusted caloric goal at his
        // body comp; fat absorbs the remainder (~88g / ~30%); protein
        // ~127g / ~20% via the 1.2 g/lb LBM ratio.
        return Profile(
            name: "Caden",
            dateOfBirth: Calendar.current.date(from: c)!,
            gender: .male, height: 70,
            bodyMassFromHealthKit: false, bodyMass: 129,
            bodyFatPercentageFromHealthKit: false, bodyFatPercentage: 12,
            activeCaloriesBurned: 700,
            proteinRatio: 1.2,
            calorieDeficit: 0,
            // netCarbsMaximum is unused in ratio modes (kept non-zero
            // so a future mode switch back to .keto has a sane starting
            // ceiling). The active math is driven by macroMode.
            netCarbsMaximum: 325,
            macroMode: .balanced)
    }


    // Persistence codec. On decode failure the store backs up the
    // blob under "profiles.corrupt" and loudly logs before init()
    // falls back to migration / the default seed.
    private static let store = UserDefaultsStore<[Profile]>(key: "profiles")


    private static func loadProfiles() -> [Profile]? {
        store.load()
    }


    private func saveProfiles() {
        Self.store.save(profiles)
    }


    // Callback fired when the active profile changes. app.swift
    // installs a handler that calls reload(...) on every per-profile
    // manager (MealIngredientMgr, AdjustmentMgr, FoodCompositeMgr) so
    // their data swaps in lock-step. The full Profile is passed (not
    // just id) because MealIngredientMgr.resetMealIngredients()
    // branches its default-meal seed by name.
    var onProfileSwitch: ((Profile) -> Void)?


    // Switch the active profile by id: re-point the active id (which
    // persists via its didSet) + notify the per-profile managers.
    // In-flight edit-screen drafts are the view's problem — ProfileEdit
    // re-snapshots its draft when the active id changes.
    func switchToProfile(_ id: String) {
        guard let next = profiles.first(where: { $0.id == id }) else { return }
        self.activeProfileId = id
        onProfileSwitch?(next)
    }


    // Add a fresh profile (cloned from the current as a template — the
    // user edits fields after switching). Switches active to the new
    // one so the page immediately reflects it.
    func addProfile() {
        var p = profile
        p.id = UUID().uuidString
        p.name = "Profile \(profiles.count + 1)"
        profiles.append(p)
        switchToProfile(p.id)
    }


    func setBodyMass(bodyMass: Double) {
        self.profile = profile.setBodyMass(bodyMass: bodyMass)
        serialize()
    }


    func setBodyFatPercentage(bodyFatPercentage: Double) {
        self.profile = profile.setBodyFatPercentage(bodyFatPercentage: bodyFatPercentage)
        serialize()
    }


    // Set / clear this profile's per-Food default amount. amount > 0
    // sets an override; <= 0 removes it so the Ingredient/Food-level
    // fallback applies again. Reassigning `profile` triggers didSet
    // which mirrors into `profiles` and persists.
    func setDefault(foodName: String, amount: Double) {
        var p = profile
        if amount > 0 {
            p.defaults[foodName] = amount
        } else {
            p.defaults.removeValue(forKey: foodName)
        }
        profile = p
    }


    // Set / clear this profile's preferred variant for a Food.
    // ingredientName empty/nil removes the override so the Food's
    // global currentIngredientName applies again.
    func setFoodMember(foodName: String, ingredientName: String?) {
        var p = profile
        if let name = ingredientName, !name.isEmpty {
            p.foodMember[foodName] = name
        } else {
            p.foodMember.removeValue(forKey: foodName)
        }
        profile = p
    }


    // Force a persist now. With the single-source-of-truth model, every
    // edit to `profile` already wrote into `profiles` (which writes JSON
    // via its didSet) and `activeProfileId` already persisted via its
    // didSet. This explicit flush is kept for callers that rely on it
    // (e.g. ProfileEdit's Save) and re-stamps the active id defensively.
    func serialize() {
        saveProfiles()
        UserDefaults.standard.set(activeProfileId, forKey: "activeProfileId")
    }
}


// =============================================================
// MacroMode — selects how protein/carbs/fat goals are derived.
//
//   .keto: legacy carb-ceiling algorithm. Protein from LBM x ratio,
//          netCarbsMaximum is a hard ceiling, fat absorbs the rest.
//
//   ratio modes: fat goal = caloricGoal x preset_fat% / 9. Protein
//          uses LBM x ratio as a FLOOR (so a growing kid never
//          undershoots growth-protein) and the preset's protein%
//          can raise it; if so, the extra protein eats carbs first
//          (fat stays at the preset %). Net carbs becomes a derived
//          target, not an editable ceiling.
//
// Splits below come from the AMDR adolescent envelope (10-30 / 45-65
// / 25-35) crossed with diet-religion conventions. See MacroModeDetail
// (chevron on the ProfileEdit Base section) for the research notes.
// =============================================================
enum MacroMode: String, ValueType, Identifiable {
    case keto
    case lowCarb
    case mediterranean
    case balanced
    case athlete

    var id: String { rawValue }

    // ValueType requirements (Picker uses formattedString as the
    // row label).
    func formattedString(_ precision: Int) -> String { label }
    func singular() -> Bool { true }

    var label: String {
        switch self {
        case .keto:          return "Keto"
        case .lowCarb:       return "Low-Carb (non-keto)"
        case .mediterranean: return "Mediterranean"
        case .balanced:      return "Balanced (USDA)"
        case .athlete:       return "Athlete / Performance"
        }
    }

    // (protein%, carbs%, fat%) for ratio modes. Keto returns nil so
    // callers know to use the legacy carb-ceiling math.
    var split: (protein: Double, carbs: Double, fat: Double)? {
        switch self {
        case .keto:          return nil
        case .lowCarb:       return (25, 30, 45)
        case .mediterranean: return (18, 42, 40)
        case .balanced:      return (20, 55, 25)
        case .athlete:       return (20, 60, 20)
        }
    }
}


struct Profile: Codable, Identifiable, Equatable {
    // id + name are new (multi-profile support). Both are filled in
    // on migration of older single-profile JSON via init(from:).
    var id: String
    var name: String
    var dateOfBirth: Date
    var gender: Gender
    var height: Int
    var bodyMassFromHealthKit: Bool
    var bodyMass: Double
    var bodyFatPercentageFromHealthKit: Bool
    var bodyFatPercentage: Double
    var activeCaloriesBurned: Double
    var proteinRatio: Double
    var calorieDeficit: Int
    var netCarbsMaximum: Double
    // Per-profile overrides of a Food's defaultAmount (the seed amount
    // when that Food is added to a meal). Keyed by Food name. Empty for
    // older persisted profiles (custom decoder defaults to [:]).
    var defaults: [String: Double]
    // Per-profile preferred member (variant) for each Food. Keyed by
    // Food name; value is an Ingredient name. When set, this profile's
    // meal rows resolve to that variant instead of the Food's global
    // currentIngredientName. Per-row `selectedMemberName` still wins
    // over this (explicit beats default). Empty for older persisted
    // profiles (custom decoder defaults to [:]).
    var foodMember: [String: String]
    // Which macro algorithm drives this profile's goals. Existing
    // single-profile JSON has no value -> custom decoder defaults to
    // .keto (preserves prior behavior). Newly added profiles default
    // to .balanced (safer for non-keto humans).
    var macroMode: MacroMode


    // Memberwise init. The `proteins` subsystem was removed; Codable
    // is now auto-synthesized (encode side; the decoder below is
    // custom for backward compatibility). Old UserDefaults JSON may
    // still carry `proteins` / `meat` / `meatAmount` keys — the
    // decoder ignores unknown keys, so pre-refactor profiles continue
    // to load and the next save drops the stale keys from disk.
    init(id: String = UUID().uuidString, name: String = "Profile",
         dateOfBirth: Date, gender: Gender, height: Int,
         bodyMassFromHealthKit: Bool, bodyMass: Double,
         bodyFatPercentageFromHealthKit: Bool, bodyFatPercentage: Double,
         activeCaloriesBurned: Double, proteinRatio: Double,
         calorieDeficit: Int, netCarbsMaximum: Double,
         defaults: [String: Double] = [:],
         macroMode: MacroMode = .keto,
         foodMember: [String: String] = [:]) {
        self.id = id
        self.name = name
        self.dateOfBirth = dateOfBirth
        self.gender = gender
        self.height = height
        self.bodyMassFromHealthKit = bodyMassFromHealthKit
        self.bodyMass = bodyMass
        self.bodyFatPercentageFromHealthKit = bodyFatPercentageFromHealthKit
        self.bodyFatPercentage = bodyFatPercentage
        self.activeCaloriesBurned = activeCaloriesBurned
        self.proteinRatio = proteinRatio
        self.calorieDeficit = calorieDeficit
        self.netCarbsMaximum = netCarbsMaximum
        self.defaults = defaults
        self.macroMode = macroMode
        self.foodMember = foodMember
    }


    // Custom decoder — Swift's auto-synthesized decoder requires every
    // property to be present in the JSON, but id/name/defaults/
    // macroMode are new. Read them with decodeIfPresent so pre-
    // multi-profile JSON keeps loading; ProfileMgr stamps migration
    // values in init() and macroMode defaults to .keto (preserves
    // prior carb-ceiling behavior for existing profiles).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.name = (try? c.decode(String.self, forKey: .name)) ?? ""
        self.dateOfBirth = try c.decode(Date.self, forKey: .dateOfBirth)
        self.gender = try c.decode(Gender.self, forKey: .gender)
        self.height = try c.decode(Int.self, forKey: .height)
        self.bodyMassFromHealthKit = try c.decode(Bool.self, forKey: .bodyMassFromHealthKit)
        self.bodyMass = try c.decode(Double.self, forKey: .bodyMass)
        self.bodyFatPercentageFromHealthKit = try c.decode(Bool.self, forKey: .bodyFatPercentageFromHealthKit)
        self.bodyFatPercentage = try c.decode(Double.self, forKey: .bodyFatPercentage)
        self.activeCaloriesBurned = try c.decode(Double.self, forKey: .activeCaloriesBurned)
        self.proteinRatio = try c.decode(Double.self, forKey: .proteinRatio)
        self.calorieDeficit = try c.decode(Int.self, forKey: .calorieDeficit)
        self.netCarbsMaximum = try c.decode(Double.self, forKey: .netCarbsMaximum)
        self.defaults = (try? c.decode([String: Double].self, forKey: .defaults)) ?? [:]
        self.macroMode = (try? c.decode(MacroMode.self, forKey: .macroMode)) ?? .keto
        self.foodMember = (try? c.decode([String: String].self, forKey: .foodMember)) ?? [:]
    }


    func setBodyMass(bodyMass: Double) -> Profile {
        var p = self
        p.bodyMass = bodyMass
        return p
    }


    func setBodyFatPercentage(bodyFatPercentage: Double) -> Profile {
        var p = self
        p.bodyFatPercentage = bodyFatPercentage
        return p
    }


    // ---------------------------------------------------------------
    // Metric / goal accessors. The actual math now lives in the
    // ProfileMetrics value type (below), computed once from a Profile
    // snapshot. These thin accessors delegate to ProfileMetrics(self)
    // so existing call sites (profile.bmi, profile.proteinGoal, …) keep
    // working unchanged. The no-op setters are retained because several
    // ProfileEdit rows bind `$draft.X` even for read-only derived
    // values; the binding requires a settable property.
    // ---------------------------------------------------------------

    var age: Double {
        set {}
        get { ProfileMetrics(self).age }
    }


    var bodyMassKg: Double {
        set {}
        get { ProfileMetrics(self).bodyMassKg }
    }


    var heightCm: Double {
        set {}
        get { ProfileMetrics(self).heightCm }
    }


    var bodyMassIndex: Double {
        set {}
        get { ProfileMetrics(self).bodyMassIndex }
    }


    var fatMass: Double {
        set {}
        get { ProfileMetrics(self).fatMass }
    }


    var leanBodyMass: Double {
        set {}
        get { ProfileMetrics(self).leanBodyMass }
    }


    var caloriesBaseMetabolicRate: Double {
        set {}
        get { ProfileMetrics(self).caloriesBaseMetabolicRate }
    }


    var caloriesResting: Double {
        set {}
        get { ProfileMetrics(self).caloriesResting }
    }


    var caloriesGoalUnadjusted: Double {
        set {}
        get { ProfileMetrics(self).caloriesGoalUnadjusted }
    }


    var fatGoalUnadjusted: Double {
        set {}
        get { ProfileMetrics(self).fatGoalUnadjusted }
    }


    var fiberMinimumUnadjusted: Double {
        set {}
        get { ProfileMetrics(self).fiberMinimumUnadjusted }
    }


    var proteinGoalUnadjusted: Double {
        set {}
        get { ProfileMetrics(self).proteinGoalUnadjusted }
    }


    var effectiveNetCarbsMaximumUnadjusted: Double {
        ProfileMetrics(self).effectiveNetCarbsMaximumUnadjusted
    }


    var fatGoalPercentageUnadjusted: Double {
        set {}
        get { ProfileMetrics(self).fatGoalPercentageUnadjusted }
    }


    var netCarbsMaximumPercentageUnadjusted: Double {
        set {}
        get { ProfileMetrics(self).netCarbsMaximumPercentageUnadjusted }
    }


    var proteinGoalPercentageUnadjusted: Double {
        set {}
        get { ProfileMetrics(self).proteinGoalPercentageUnadjusted }
    }


    var caloriesGoal: Double {
        set {}
        get { ProfileMetrics(self).caloriesGoal }
    }


    var fiberMinimum: Double {
        set {}
        get { ProfileMetrics(self).fiberMinimum }
    }


    var proteinGoal: Double {
        set {}
        get { ProfileMetrics(self).proteinGoal }
    }


    var fatGoal: Double {
        set {}
        get { ProfileMetrics(self).fatGoal }
    }


    var effectiveNetCarbsMaximum: Double {
        ProfileMetrics(self).effectiveNetCarbsMaximum
    }


    var fatGoalPercentage: Double {
        set {}
        get { ProfileMetrics(self).fatGoalPercentage }
    }


    var netCarbsMaximumPercentage: Double {
        set {}
        get { ProfileMetrics(self).netCarbsMaximumPercentage }
    }


    var proteinGoalPercentage: Double {
        set {}
        get { ProfileMetrics(self).proteinGoalPercentage }
    }


    var waterLiters: Double {
        set {}
        get { ProfileMetrics(self).waterLiters }
    }
}


// =============================================================
// ProfileMetrics — all BMI / Mifflin-St-Jeor BMR / TDEE / body-comp /
// macro-goal math for a Profile, computed from a single immutable
// snapshot. Profile's metric accessors delegate here so the math lives
// in one place. Pure value type, no persistence, no @Published — cheap
// to construct on demand (it just copies the scalar inputs).
//
// Numeric behavior is identical to the prior inline computed properties
// on Profile; only the location of the formulas changed.
// =============================================================
struct ProfileMetrics {

    // Snapshot inputs copied from the source Profile.
    let dateOfBirth: Date
    let gender: Gender
    let height: Int
    let bodyMass: Double
    let bodyFatPercentage: Double
    let activeCaloriesBurned: Double
    let proteinRatio: Double
    let calorieDeficit: Int
    let netCarbsMaximum: Double
    let macroMode: MacroMode


    init(_ p: Profile) {
        self.dateOfBirth = p.dateOfBirth
        self.gender = p.gender
        self.height = p.height
        self.bodyMass = p.bodyMass
        self.bodyFatPercentage = p.bodyFatPercentage
        self.activeCaloriesBurned = p.activeCaloriesBurned
        self.proteinRatio = p.proteinRatio
        self.calorieDeficit = p.calorieDeficit
        self.netCarbsMaximum = p.netCarbsMaximum
        self.macroMode = p.macroMode
    }


    // ---- Body composition ----

    var age: Double {
        Double(Calendar.current.dateComponents([.month], from: self.dateOfBirth, to: Date()).month ?? 0) / 12.0
    }

    var bodyMassKg: Double {
        (self.bodyMass * 0.453592).round(1)
    }

    var heightCm: Double {
        Double(self.height) * 2.54
    }

    var bodyMassIndex: Double {
        (self.bodyMass / Double(self.height * self.height)) * 703
    }

    var fatMass: Double {
        (self.bodyMass * (self.bodyFatPercentage / 100)).round(1)
    }

    var leanBodyMass: Double {
        (self.bodyMass - self.fatMass).round(1)
    }


    // ---- Energy ----

    // Mifflin-St Jeor: 9.99·kg + 6.25·cm − 4.92·age, then +5 (male)
    // or −161 (female). The sex constant is ADDED after the age term
    // is subtracted — a previous version distributed the minus sign
    // over it, overstating female BMR by 322 kcal.
    var caloriesBaseMetabolicRate: Double {
        let base = (self.bodyMassKg * 9.99) + (self.heightCm * 6.25) - (self.age * 4.92)
        return gender == Gender.male ? base + 5 : base - 161
    }

    var caloriesResting: Double {
        self.caloriesBaseMetabolicRate * 1.2
    }

    var caloriesGoalUnadjusted: Double {
        self.caloriesResting + Double(self.activeCaloriesBurned)
    }

    var caloriesGoal: Double {
        self.caloriesGoalUnadjusted - (self.caloriesGoalUnadjusted * (Double(self.calorieDeficit) / 100))
    }


    // ---- Macro goals ----
    //
    // The protein / fat / net-carb goals share one parameterized
    // formula set keyed on a caloric goal. `macroGoals(forCalories:)`
    // computes all three at once; the unadjusted variant feeds it the
    // gross caloric goal, the adjusted variant feeds it the net (post-
    // deficit) goal. This is the single source of the macro math.

    struct MacroGoals {
        let protein: Double      // grams
        let fat: Double          // grams
        let netCarbs: Double     // grams (effective target / ceiling)
    }


    // Compute protein / fat / net-carb grams for a given caloric goal.
    //   .keto:  protein = LBM × ratio (floor only);
    //           netCarbs = stored ceiling;
    //           fat absorbs the remainder.
    //   ratio:  fat  = cals × fat% / 9;
    //           protein = max(LBM × ratio, cals × protein% / 4);
    //           netCarbs = whatever's left after protein + fat.
    func macroGoals(forCalories cals: Double) -> MacroGoals {
        let lbmFloor = self.leanBodyMass * self.proteinRatio
        if let s = macroMode.split {
            let protein = max(lbmFloor, cals * s.protein / 100 / 4)
            let fat = cals * s.fat / 100 / 9
            let netCarbs = max(0, cals - (protein * 4) - (fat * 9)) / 4
            return MacroGoals(protein: protein, fat: fat, netCarbs: netCarbs)
        }
        let protein = lbmFloor
        let netCarbs = self.netCarbsMaximum
        // Clamped at 0 like the ratio branch's netCarbs — a small
        // calorie goal with a high protein floor can otherwise
        // produce a negative fat target.
        let fat = max(0, (cals - ((protein + netCarbs) * 4)) / 9)
        return MacroGoals(protein: protein, fat: fat, netCarbs: netCarbs)
    }


    // ---- Gross (no-deficit) macro goals ----

    var fatGoalUnadjusted: Double {
        macroGoals(forCalories: self.caloriesGoalUnadjusted).fat
    }

    var fiberMinimumUnadjusted: Double {
        (self.caloriesGoalUnadjusted / 1000) * 14
    }

    var proteinGoalUnadjusted: Double {
        macroGoals(forCalories: self.caloriesGoalUnadjusted).protein
    }

    // Effective carb target in grams. Keto: the stored ceiling. Ratio
    // modes: whatever's left after protein and fat.
    var effectiveNetCarbsMaximumUnadjusted: Double {
        macroGoals(forCalories: self.caloriesGoalUnadjusted).netCarbs
    }

    var fatGoalPercentageUnadjusted: Double {
        ((self.fatGoalUnadjusted * 9) / self.caloriesGoalUnadjusted) * 100
    }

    var netCarbsMaximumPercentageUnadjusted: Double {
        ((self.effectiveNetCarbsMaximumUnadjusted * 4) / self.caloriesGoalUnadjusted) * 100
    }

    var proteinGoalPercentageUnadjusted: Double {
        ((self.proteinGoalUnadjusted * 4) / self.caloriesGoalUnadjusted) * 100
    }


    // ---- Net (deficit-applied) macro goals ----

    var fiberMinimum: Double {
        (self.caloriesGoal / 1000) * 14
    }

    var proteinGoal: Double {
        macroGoals(forCalories: self.caloriesGoal).protein
    }

    var fatGoal: Double {
        macroGoals(forCalories: self.caloriesGoal).fat
    }

    // Net (deficit-applied) effective carb target — used by the dashboard
    // and macrosMgr as the daily carb-goal scale.
    var effectiveNetCarbsMaximum: Double {
        macroGoals(forCalories: self.caloriesGoal).netCarbs
    }

    var fatGoalPercentage: Double {
        ((self.fatGoal * 9) / self.caloriesGoal) * 100
    }

    var netCarbsMaximumPercentage: Double {
        ((self.effectiveNetCarbsMaximum * 4) / self.caloriesGoal) * 100
    }

    var proteinGoalPercentage: Double {
        ((self.proteinGoal * 4) / self.caloriesGoal) * 100
    }


    // ---- Hydration ----

    var waterLiters: Double {
        (self.bodyMass / 2) * 0.029574
    }
}
