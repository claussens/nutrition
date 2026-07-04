import SwiftUI


@main
struct app: App {

    // The three per-profile managers (MealIngredientMgr,
    // AdjustmentMgr, FoodCompositeMgr) need ProfileMgr's active id at
    // construction time, and need their `reload(forProfileId:)` wired
    // to ProfileMgr.onProfileSwitch. The custom init below assembles
    // them in order, threads the active id, and installs the reload
    // callback so switching the profile swaps all three managers'
    // data in lock-step. Shared managers (Ingredient/Food/Macros/V&M/
    // DayLog) stay singletons because their data isn't per-profile.
    @StateObject var ingredientMgr: IngredientMgr
    @StateObject var adjustmentMgr: AdjustmentMgr
    @StateObject var mealIngredientMgr: MealIngredientMgr
    @StateObject var macrosMgr: MacrosMgr
    @StateObject var profileMgr: ProfileMgr
    @StateObject var vitaminMineralMgr: VitaminMineralMgr
    @StateObject var foodMgr: FoodMgr
    @StateObject var foodCompositeMgr: FoodCompositeMgr
    @StateObject var dayLogMgr: DayLogMgr


    init() {
        // Load the config data set (bundled YAML on first launch, the last
        // successful GitHub refresh thereafter) BEFORE constructing the managers,
        // which now seed themselves from ConfigStore instead of in-code literals.
        ConfigStore.shared.loadInitial()

        let pm = ProfileMgr()
        let active = pm.profile
        let mim = MealIngredientMgr(profileId: active.id, profileName: active.name)
        let am  = AdjustmentMgr(profileId: active.id)
        let fcm = FoodCompositeMgr(profileId: active.id)
        // [weak] avoids retaining the managers via the closure they
        // hand to ProfileMgr (each is already retained by the
        // StateObject wrappers below).
        pm.onProfileSwitch = { [weak mim, weak am, weak fcm] next in
            mim?.reload(forProfileId: next.id, profileName: next.name)
            am?.reload(forProfileId: next.id)
            fcm?.reload(forProfileId: next.id)
        }
        _profileMgr        = StateObject(wrappedValue: pm)
        _mealIngredientMgr = StateObject(wrappedValue: mim)
        _adjustmentMgr     = StateObject(wrappedValue: am)
        _foodCompositeMgr  = StateObject(wrappedValue: fcm)
        _ingredientMgr     = StateObject(wrappedValue: IngredientMgr())
        _macrosMgr         = StateObject(wrappedValue: MacrosMgr())
        _vitaminMineralMgr = StateObject(wrappedValue: VitaminMineralMgr())
        _foodMgr           = StateObject(wrappedValue: FoodMgr())
        _dayLogMgr         = StateObject(wrappedValue: DayLogMgr(activeProfileId: active.id))
    }


    var body: some Scene {
        return WindowGroup {
            Tabs()
              .environmentObject(ingredientMgr)
              .environmentObject(adjustmentMgr)
              .environmentObject(mealIngredientMgr)
              .environmentObject(macrosMgr)
              .environmentObject(profileMgr)
              .environmentObject(vitaminMineralMgr)
              .environmentObject(foodMgr)
              .environmentObject(foodCompositeMgr)
              .environmentObject(dayLogMgr)
              .task {
                  #if DEBUG
                  // Test harness: when launched with a GITHUB_API_KEY in the
                  // environment, fetch the live config from the repo on startup
                  // so the Simulator can verify the network load path without a
                  // manual Refresh tap. Compiled out of release builds.
                  guard ProcessInfo.processInfo.environment["GITHUB_API_KEY"] != nil else { return }
                  do {
                      let result = try await ConfigSync.refresh()
                      print("[DEBUG auto-refresh] \(result)")
                  } catch {
                      print("[DEBUG auto-refresh] FAILED: \(error)")
                  }
                  #endif
              }
        }
    }
}
