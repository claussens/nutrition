import SwiftUI


// Meal-cost breakdown. Pushed from the $ icon in the MealList
// compact toolbar. Lists every meal ingredient by how much it
// contributes to the meal's cost, most expensive first, so the
// user can see what's actually driving the grocery bill.
//
// Cost contribution per row:
//   costPerGram   = ingredient.totalCost / ingredient.totalGrams
//   gramsConsumed = mealIngredient.amount × ingredient.consumptionGrams
//   contribution  = costPerGram × gramsConsumed
//
// Ingredients without pricing (totalGrams == 0) contribute 0 and
// sort to the bottom — they're shown so the user knows they're
// unpriced rather than silently dropped. All rows render in the
// primary text color (no active/inactive distinction here).
struct IngredientCostDetail: View {

    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var ingredientMgr: IngredientMgr
    @EnvironmentObject var mealIngredientMgr: MealIngredientMgr
    @EnvironmentObject var foodMgr: FoodMgr
    @EnvironmentObject var profileMgr: ProfileMgr


    var body: some View {
        let rows = sortedRows()
        let total = rows.reduce(0) { $0 + $1.cost }

        List {
            ForEach(rows, id: \.mealIngredient.id) { row in
                HStack {
                    Text(row.mealIngredient.name)
                      .font(.callout)
                    Spacer()
                    Text(dollars(row.cost))
                      .font(.caption)
                }
                  .foregroundColor(Color.theme.blackWhite)
            }
        }
          .listStyle(.plain)
          .navigationTitle("Meal Cost  \(dollars(total))")
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
              ToolbarItem(placement: .primaryAction) {
                  Button("Done") {
                      presentationMode.wrappedValue.dismiss()
                  }
                    .foregroundColor(Color.theme.blueYellow)
              }
          }
    }


    private func sortedRows() -> [(mealIngredient: MealIngredient, cost: Double)] {
        // Row-aware Food→variant resolution (selected member →
        // profile pref → Food default) — the SAME lookup the macro
        // engine uses, so a row priced here is the row counted there.
        let resolver = MealResolver(ingredientMgr: ingredientMgr,
                                    foodMgr: foodMgr,
                                    profile: profileMgr.profile)
        let pairs: [(mealIngredient: MealIngredient, cost: Double)] =
            mealIngredientMgr.mealIngredients
              .filter { $0.amount > 0 }
              .compactMap { mi in
                // Category placeholders are not real foods — exclude.
                if mi.isFoodTypeSlot { return nil }
                if mi.isComposite {
                    return (mi, compositeCost(mi, ingredientMgr, foodMgr))
                }
                guard let ing = resolver.resolvedIngredient(mi) else { return nil }
                return (mi, costContribution(mi, ing))
            }
        return pairs.sorted { $0.cost > $1.cost }
    }


    private func costContribution(_ mi: MealIngredient, _ ing: Ingredient) -> Double {
        let grams = ing.effectiveTotalGrams
        guard grams > 0 else { return 0 }
        let costPerGram = ing.totalCost / grams
        let gramsConsumed = mi.amount * foodMgr.consumptionGrams(for: ing)
        return costPerGram * gramsConsumed
    }


    private func dollars(_ v: Double) -> String {
        String(format: "$%.2f", v)
    }
}
