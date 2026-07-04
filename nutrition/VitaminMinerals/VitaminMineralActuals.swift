import Foundation


// All vitamin/mineral types in a fixed display order.  Mirrors the
// order used by VitaminMineralMgr.getAll().  Derived from the
// nutrient catalog (alphabetical by field id — identical to the
// historical hand-maintained order).
let vitaminMineralOrder: [VitaminMineralType] = NutrientCatalog.dashboardOrder


// Total each vitamin/mineral across all meal ingredients (a meal is
// exactly the rows present). Returns a dictionary keyed by
// VitaminMineralType.  Rows resolve through MealResolver — the SAME
// Food→variant resolution the macro engine uses — so a row named
// "Eggs" contributes its selected variant's nutrients instead of
// silently contributing nothing. Composite rows contribute the sum
// of their parts. Unresolvable rows are skipped (no crash). Values
// are in the same units as the corresponding fields on Ingredient.
func computeVitaminMineralActuals(
    mealIngredients: [MealIngredient],
    resolver: MealResolver
) -> [VitaminMineralType: Double] {

    var totals: [VitaminMineralType: Double] = [:]

    for mealIngredient in mealIngredients {
        for (ingredient, servings) in resolvedPortions(of: mealIngredient, resolver: resolver) {
            for type in vitaminMineralOrder {
                totals[type, default: 0] += nutrientValue(of: ingredient, for: type) * servings
            }
        }
    }

    return totals
}


// Resolve a meal row to the (ingredient, servings) portions it
// contributes: one pair for an ordinary row, one per component for a
// composite, none for category placeholders / unresolvable rows.
// Shared by the totals and the per-nutrient drill-down so the two
// can never disagree.
func resolvedPortions(
    of mealIngredient: MealIngredient,
    resolver: MealResolver
) -> [(ingredient: Ingredient, servings: Double)] {

    // Category placeholders are not real foods — no contribution.
    if mealIngredient.isFoodTypeSlot { return [] }

    if mealIngredient.isComposite {
        return mealIngredient.compositeParts.compactMap { part in
            guard let ing = resolver.ingredientMgr.getByName(name: part.selectedVariantName),
                  ing.servingSize > 0 else { return nil }
            let servings = (part.amount * resolver.foodMgr.consumptionGrams(for: ing)) / ing.servingSize
            return (ing, servings)
        }
    }

    guard let ingredient = resolver.resolvedIngredient(mealIngredient),
          ingredient.servingSize > 0 else { return [] }
    let servings = (mealIngredient.amount * resolver.foodMgr.consumptionGrams(for: ingredient)) / ingredient.servingSize
    return [(ingredient, servings)]
}


// One ingredient's contribution to a single vitamin/mineral, used by
// the per-nutrient drill-down view.
struct VitaminMineralContribution: Identifiable {
    let id: String
    let ingredientName: String
    let amount: Double
    let consumptionUnit: Unit
    let contribution: Double
}


// Per-ingredient contributions to a single nutrient, sorted
// descending by contribution.  Ingredients that contribute zero
// (because the nutrient isn't recorded for them) are omitted.
func contributorsTo(
    nutrient: VitaminMineralType,
    mealIngredients: [MealIngredient],
    resolver: MealResolver
) -> [VitaminMineralContribution] {

    var contributions: [VitaminMineralContribution] = []

    for mealIngredient in mealIngredients {
        let portions = resolvedPortions(of: mealIngredient, resolver: resolver)
        let contribution = portions.reduce(0) {
            $0 + nutrientValue(of: $1.ingredient, for: nutrient) * $1.servings
        }

        if contribution > 0 {
            // Composite rows display as pieces; ordinary rows use the
            // resolved ingredient's consumption unit.
            let unit: Unit = mealIngredient.isComposite
                ? .piece
                : portions.first.map { resolver.foodMgr.consumptionUnit(for: $0.ingredient) } ?? .gram
            contributions.append(VitaminMineralContribution(
                id: mealIngredient.id,
                ingredientName: mealIngredient.name,
                amount: mealIngredient.amount,
                consumptionUnit: unit,
                contribution: contribution
            ))
        }
    }

    return contributions.sorted { $0.contribution > $1.contribution }
}


// One row in the "all sources" table — every ingredient in the
// database that records a non-zero amount of this nutrient, ranked
// by per-gram density. Tells the user *what to eat more of* to hit
// the RDA when their current meal is short.
struct IngredientNutrientDensity: Identifiable {
    let id: String           // ingredient name (unique within db)
    let name: String
    let gramsForMin: Double  // grams of this ingredient to hit RDA min;
                             // 0 when min is undefined (use sentinel)
    let perHundredGrams: Double  // amount of nutrient per 100g
}


// All ingredients in the database that contribute to `nutrient`,
// sorted most → least dense (per-gram). `rdaMin` is used to compute
// "grams of X to reach minimum"; pass 0 when no min applies and the
// caller renders a "—" instead.
func allContributorsFor(
    nutrient: VitaminMineralType,
    rdaMin: Double,
    ingredientMgr: IngredientMgr
) -> [IngredientNutrientDensity] {

    var rows: [IngredientNutrientDensity] = []

    for ingredient in ingredientMgr.ingredients {
        guard ingredient.servingSize > 0 else { continue }
        let perServing = nutrientValue(of: ingredient, for: nutrient)
        guard perServing > 0 else { continue }

        let densityPerGram = perServing / ingredient.servingSize
        let gramsForMin = rdaMin > 0 ? rdaMin / densityPerGram : 0
        let per100g = densityPerGram * 100

        rows.append(IngredientNutrientDensity(
            id: ingredient.name,
            name: ingredient.name,
            gramsForMin: gramsForMin,
            perHundredGrams: per100g
        ))
    }

    // Descending by per-gram density — top of the list is the best
    // source per gram. Equivalent to ascending by gramsForMin.
    return rows.sorted { $0.perHundredGrams > $1.perHundredGrams }
}


// Pull a nutrient's raw per-serving value off an ingredient and
// return it in the unit reported by VitaminMineral.unit() — the same
// unit min()/max() use, so callers can compare freely.
//
// The keypath and the stored-unit → RDA-unit conversion factor both
// come from the descriptor (copper mg→mcg ×1000, vitamin D mcg→IU
// ×40 — 1 mcg vitamin D = 40 IU — live in NutrientCatalog only).
// Internal (not file-private) so MealIngredientDetail can reuse the
// same mapping + unit conversions when showing per-ingredient
// contributions; otherwise the detail page double-shows raw mg/mcg
// for copper and raw mcg for vitamin D, breaking unit consistency.
func nutrientValue(of ingredient: Ingredient, for type: VitaminMineralType) -> Double {
    guard let d = NutrientCatalog.byVMType[type] else { return 0 }
    return ingredient[keyPath: d.ingredient] * d.rdaFactor
}
