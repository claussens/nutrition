import SwiftUI

struct Dashboard: View {
    // Body-composition / activity gauges (Weight, Fat%, Activity, Deficit,
    // Ratio) used to live at the top of this view; they were moved to the
    // DailySummary long-hold page since they're reference info that doesn't
    // change as the user logs meals.
    //
    // The horizontal Calories Bar that used to live below the macros was
    // replaced with a Calories donut gauge in the macro row — visually
    // consistent with the other gauges and centered on the *target*
    // intake (caloriesGoal) so being at target reads as 100% complete
    // rather than the old "27% deficit" framing that mis-cued progress.
    // Fiber was removed from the row to keep the gauge count at 4.
    //
    // Tap routing (replaced the old "tap-anywhere → DailySummary"):
    //   Fat / NCarbs / Protein donut → IngredientNutrientDetail sheet
    //     ranking every meal ingredient by that macro per 100g.
    //   Calories donut                → DailySummary (the existing
    //     long-hold page; toolbar's info.circle button does the same).

    let caloriesGoal: Double           // deficit-adjusted target; 100% on the dial
    let caloriesGoalUnadjusted: Double // 100% TDEE — second gauge line ("% / total (delta)")
    let calories: Double

    let fatGoal: Double
    let netCarbsMaximum: Double
    let proteinGoal: Double

    let fat: Double
    let netCarbs: Double
    let protein: Double

    @Binding var showSummary: Bool

    // Dashboard receives these managers from its parent's
    // environment (MealList already injects them). They're captured
    // here so the per-macro IngredientNutrientDetail sheets can run
    // the shared MealResolver (Food→variant) lookup themselves —
    // sheets get a fresh environment, so each must be re-injected.
    @EnvironmentObject var ingredientMgr: IngredientMgr
    @EnvironmentObject var mealIngredientMgr: MealIngredientMgr
    @EnvironmentObject var foodMgr: FoodMgr
    @EnvironmentObject var profileMgr: ProfileMgr

    @State private var showFatDetail: Bool = false
    @State private var showNCarbsDetail: Bool = false
    @State private var showProteinDetail: Bool = false

    var body: some View {
        // Pin macros + calories to the top of the frame; explicit
        // HStack height (110pt) reserves room for the offset gauge
        // titles so they don't bleed up into the toolbar.
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer()
                Gauge(title: "Fat",      titleFontColor: Color.theme.blackWhite, titleFontSize: 13.6, fat,                          actualFontSize: 14.4,                     fatGoal,         goalFontSize: 9.6, annotationFontColor: Color.theme.blueYellow, unit: "grams", unitFontSize: 8, progressLineBackground: Color.theme.progressLineBackground,                 scale: 1.18)
                  // contentShape on each Gauge makes the donut's
                  // empty interior tappable too — without it only
                  // the rendered ring + label glyphs would catch
                  // taps, which feels broken on the negative space.
                  .contentShape(Rectangle())
                  .onTapGesture { showFatDetail = true }
                Spacer()
                Gauge(title: "NCarbs",   titleFontColor: Color.theme.blackWhite, titleFontSize: 13.6, netCarbs, actualFontSize: 14.4, actualPrecision: 1, netCarbsMaximum, goalFontSize: 9.6, annotationFontColor: Color.theme.blueYellow, unit: "grams", unitFontSize: 8, progressLineBackground: Color.theme.progressLineBackground, type: .ceiling, scale: 1.18)
                  .contentShape(Rectangle())
                  .onTapGesture { showNCarbsDetail = true }
                Spacer()
                Gauge(title: "Protein",  titleFontColor: Color.theme.blackWhite, titleFontSize: 13.6, protein,                      actualFontSize: 14.4,                     proteinGoal,     goalFontSize: 9.6, annotationFontColor: Color.theme.blueYellow, unit: "grams", unitFontSize: 8, progressLineBackground: Color.theme.progressLineBackground,                 scale: 1.18)
                  .contentShape(Rectangle())
                  .onTapGesture { showProteinDetail = true }
                Spacer()
                Gauge(title: "Calories", titleFontColor: Color.theme.blackWhite, titleFontSize: 13.6, calories,                     actualFontSize: 14.4,                     caloriesGoal,    goalFontSize: 9.6, annotationFontColor: Color.theme.blueYellow, unit: "cals",   unitFontSize: 8, progressLineBackground: Color.theme.progressLineBackground,                 showGoalDelta: true, secondaryGoal: caloriesGoalUnadjusted, scale: 1.18)
                  .contentShape(Rectangle())
                  .onTapGesture { showSummary = true }
                Spacer()
            }
              .frame(height: 165)
              .padding(.top, 8)
              .padding(.bottom, 4)
            Spacer()
        }
          // Each macro gauge presents its own IngredientNutrientDetail
          // sheet, sorted "worst → best" for the user's intent: highest
          // fat / protein per 100g first (build the meal up), lowest
          // net carbs first (avoid the offenders).
          .sheet(isPresented: $showFatDetail) {
              NavigationView {
                  IngredientNutrientDetail(title: "Fat per 100g",
                                           unit: "g",
                                           sortOrder: .descending,
                                           valueFor: { $0.fat100 })
                    .environmentObject(ingredientMgr)
                    .environmentObject(mealIngredientMgr)
                    .environmentObject(foodMgr)
                    .environmentObject(profileMgr)
              }
          }
          .sheet(isPresented: $showNCarbsDetail) {
              NavigationView {
                  IngredientNutrientDetail(title: "Net Carbs per 100g",
                                           unit: "g",
                                           sortOrder: .ascending,
                                           valueFor: { $0.netCarbs100 })
                    .environmentObject(ingredientMgr)
                    .environmentObject(mealIngredientMgr)
                    .environmentObject(foodMgr)
                    .environmentObject(profileMgr)
              }
          }
          .sheet(isPresented: $showProteinDetail) {
              NavigationView {
                  IngredientNutrientDetail(title: "Protein per 100g",
                                           unit: "g",
                                           sortOrder: .descending,
                                           valueFor: { $0.protein100 })
                    .environmentObject(ingredientMgr)
                    .environmentObject(mealIngredientMgr)
                    .environmentObject(foodMgr)
                    .environmentObject(profileMgr)
              }
          }
    }
}
