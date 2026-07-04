import SwiftUI


// Nutrients whose Tolerable Upper Intake Level (UL), per NIH, applies
// only to supplemental / fortified-food intake — not to the totals
// shown in the V&M list, which sum food + supplements.  For these the
// Max column is hidden (rendered as "—") and the over-max red name
// highlight is suppressed; comparing a food-inclusive total against a
// supplement-only ceiling is misleading (it's why magnesium showed
// min=420 > max=350 before this fix).  Per-nutrient excess implications
// are still surfaced on the contributors drill-down page.
// Internal so DailySummary can reuse the same filter when rendering
// its red-only V&M list — keeps both views in sync if the set changes.
let supplementOnlyULNutrients: Set<VitaminMineralType> = [
    .magnesium, .niacin, .folate, .vitaminE
]


struct VitaminMineralList: View {

    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var profileMgr: ProfileMgr
    @EnvironmentObject var vitaminMineralMgr: VitaminMineralMgr
    @EnvironmentObject var mealIngredientMgr: MealIngredientMgr
    @EnvironmentObject var ingredientMgr: IngredientMgr
    @EnvironmentObject var foodMgr: FoodMgr


    var body: some View {
        let actuals = computeVitaminMineralActuals(
            mealIngredients: mealIngredientMgr.mealIngredients,
            resolver: MealResolver(ingredientMgr: ingredientMgr,
                                   foodMgr: foodMgr,
                                   profile: profileMgr.profile)
        )

        return List {
            VitaminMineralRowHeader()
              .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))

            ForEach(vitaminMineralMgr.getAll(age: profileMgr.profile.age, gender: profileMgr.profile.gender)) { vitaminMineral in
                let displayedMax = supplementOnlyULNutrients.contains(vitaminMineral.name)
                    ? 0
                    : vitaminMineral.max()
                NavigationLink(destination: VitaminMineralContributors(nutrient: vitaminMineral.name)) {
                    VitaminMineralRow(name: vitaminMineral.name,
                                      min: vitaminMineral.min(),
                                      max: displayedMax,
                                      actual: actuals[vitaminMineral.name] ?? 0,
                                      unit: vitaminMineral.unit())
                }
            }
              .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
        }
    }
}
