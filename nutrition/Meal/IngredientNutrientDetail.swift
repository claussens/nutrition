import SwiftUI


// Reusable per-100g nutrient detail page. Pushed from the macro
// gauges on the Dashboard — tapping the Fat / NCarbs / Protein
// donut presents this list sorted by that macro's per-100g value
// (descending for fat & protein, ascending for net carbs). Lets
// the user quickly answer "what's contributing the most fat per
// gram in my meal?" without doing the math themselves.
//
// Includes inactive meal ingredients too, so deactivating a row
// doesn't drop it from the comparison. All rows render in the
// primary text color — no active/inactive color distinction here.
struct IngredientNutrientDetail: View {

    enum SortOrder { case ascending, descending }

    let title: String                       // e.g. "Fat per 100g"
    let unit: String                        // e.g. "g"
    let sortOrder: SortOrder
    let valueFor: (Ingredient) -> Double    // e.g. { $0.fat100 }

    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var ingredientMgr: IngredientMgr
    @EnvironmentObject var mealIngredientMgr: MealIngredientMgr
    @EnvironmentObject var foodMgr: FoodMgr
    @EnvironmentObject var profileMgr: ProfileMgr


    var body: some View {
        List {
            ForEach(sortedRows(), id: \.mealIngredient.id) { row in
                HStack {
                    Text(row.mealIngredient.name)
                      .font(.callout)
                    Spacer()
                    Text("\(row.value.formattedString(1)) \(unit)")
                      .font(.caption)
                }
                  .foregroundColor(Color.theme.blackWhite)
            }
        }
          .listStyle(.plain)
          .navigationTitle(title)
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


    // Pair each meal ingredient with its underlying Ingredient's
    // per-100g value using the shared Food→variant resolution
    // (same lookup the macro engine uses), drop rows that don't
    // resolve (category placeholders, composites), then sort.
    private func sortedRows() -> [(mealIngredient: MealIngredient, value: Double)] {
        let resolver = MealResolver(ingredientMgr: ingredientMgr,
                                    foodMgr: foodMgr,
                                    profile: profileMgr.profile)
        let pairs: [(mealIngredient: MealIngredient, value: Double)] =
            mealIngredientMgr.mealIngredients.compactMap { mi in
                guard let ing = resolver.resolvedIngredient(mi) else { return nil }
                return (mi, valueFor(ing))
            }
        switch sortOrder {
        case .ascending:  return pairs.sorted { $0.value < $1.value }
        case .descending: return pairs.sorted { $0.value > $1.value }
        }
    }
}
