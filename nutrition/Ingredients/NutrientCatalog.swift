import Foundation

// ============================================================
// NutrientCatalog — the ONE place a nutrient is described.
//
// Every nutrient the app tracks gets exactly one descriptor row
// here, and everything that used to hand-maintain its own field
// list is driven from this table:
//
//   • Ingredient.init(from:) decodes nutrient fields by looping
//     the catalog (so the flat JSON bridge and the stored
//     properties can't drift).
//   • ConfigStore's kebab→camel flat-dict bridge.
//   • VitaminMineral's rda.yaml key + RDA unit, the dashboard's
//     `vitaminMineralOrder`, and `nutrientValue(of:for:)`'s unit
//     conversions (`rdaFactor` is the only home for the copper
//     mg→mcg ×1000 and vitamin D mcg→IU ×40 conversions).
//
// To add a nutrient end-to-end: add the stored property on
// Ingredient (with `= 0` default), a case on VitaminMineralType
// if it has an RDA row — and ONE row here.
// ============================================================

struct NutrientDescriptor {

    enum Kind {
        // Top-level field in a ConfigIngredient (calories, fat,
        // fiber, net-carbs, protein) — not in the `nutrients` map.
        case coreMacro
        // Lives in the config `nutrients` map; macro-adjacent data.
        case extendedMacro
        // Lives in the config `nutrients` map; on the V&M dashboard
        // when it has an RDA row.
        case vitaminMineral
    }

    // camelCase field name — the Ingredient Codable/JSON key.
    let id: String

    // Human-readable label.
    let label: String

    // kebab-case key in the config `nutrients` map and rda.yaml.
    // (Unused for .coreMacro rows, which are top-level fields.)
    let kebabKey: String

    // Where the value lives on the runtime Ingredient.
    let ingredient: WritableKeyPath<Ingredient, Double>

    // Non-nil = this nutrient has an rda.yaml row and appears on
    // the V&M dashboard.
    let vmType: VitaminMineralType?

    // Unit NIH publishes the RDA/UL in, and the factor converting
    // the Ingredient's stored value into that unit. THE single
    // home of the copper mg→mcg (×1000) and vitamin D mcg→IU
    // (×40) conversions.
    let rdaUnit: Unit
    let rdaFactor: Double

    let kind: Kind

    init(_ id: String, _ label: String, _ kebabKey: String,
         _ ingredient: WritableKeyPath<Ingredient, Double>,
         vmType: VitaminMineralType? = nil,
         rdaUnit: Unit = .milligram,
         rdaFactor: Double = 1,
         kind: Kind) {
        self.id = id
        self.label = label
        self.kebabKey = kebabKey
        self.ingredient = ingredient
        self.vmType = vmType
        self.rdaUnit = rdaUnit
        self.rdaFactor = rdaFactor
        self.kind = kind
    }
}


enum NutrientCatalog {

    // The full table (the dashboard order is derived alphabetically
    // below). "sugarAlcohool" keeps its historical spelling — it
    // is a live Codable/JSON key.
    static let all: [NutrientDescriptor] = [
        // --- core macros (top-level config fields) ---
        NutrientDescriptor("calories", "Calories", "calories", \.calories, kind: .coreMacro),
        NutrientDescriptor("fat", "Fat", "fat", \.fat, kind: .coreMacro),
        NutrientDescriptor("fiber", "Fiber", "fiber", \.fiber, kind: .coreMacro),
        NutrientDescriptor("netCarbs", "Net Carbs", "net-carbs", \.netCarbs, kind: .coreMacro),
        NutrientDescriptor("protein", "Protein", "protein", \.protein, kind: .coreMacro),

        // --- extended macros (config `nutrients` map) ---
        NutrientDescriptor("saturatedFat", "Saturated Fat", "saturated-fat", \.saturatedFat, kind: .extendedMacro),
        NutrientDescriptor("transFat", "Trans Fat", "trans-fat", \.transFat, kind: .extendedMacro),
        NutrientDescriptor("polyunsaturatedFat", "Polyunsaturated Fat", "polyunsaturated-fat", \.polyunsaturatedFat, kind: .extendedMacro),
        NutrientDescriptor("monounsaturatedFat", "Monounsaturated Fat", "monounsaturated-fat", \.monounsaturatedFat, kind: .extendedMacro),
        NutrientDescriptor("cholesterol", "Cholesterol", "cholesterol", \.cholesterol, kind: .extendedMacro),
        NutrientDescriptor("sodium", "Sodium", "sodium", \.sodium, kind: .extendedMacro),
        NutrientDescriptor("carbohydrates", "Carbohydrates", "carbohydrates", \.carbohydrates, kind: .extendedMacro),
        NutrientDescriptor("sugar", "Sugar", "sugar", \.sugar, kind: .extendedMacro),
        NutrientDescriptor("addedSugar", "Added Sugar", "added-sugar", \.addedSugar, kind: .extendedMacro),
        NutrientDescriptor("sugarAlcohool", "Sugar Alcohol", "sugar-alcohol", \.sugarAlcohool, kind: .extendedMacro),

        // --- vitamins & minerals ---
        NutrientDescriptor("omega3", "Omega-3", "omega3", \.omega3, kind: .vitaminMineral),
        NutrientDescriptor("vitaminD", "Vitamin D", "vitamin-d", \.vitaminD,
                           vmType: .vitaminD,
                           rdaUnit: .internationalUnit, rdaFactor: 40,   // stored mcg → IU
                           kind: .vitaminMineral),
        NutrientDescriptor("calcium", "Calcium", "calcium", \.calcium,
                           vmType: .calcium, kind: .vitaminMineral),
        NutrientDescriptor("iron", "Iron", "iron", \.iron,
                           vmType: .iron, kind: .vitaminMineral),
        NutrientDescriptor("potassium", "Potassium", "potassium", \.potassium,
                           vmType: .potassium, kind: .vitaminMineral),
        NutrientDescriptor("vitaminA", "Vitamin A", "vitamin-a", \.vitaminA,
                           vmType: .vitaminA,
                           rdaUnit: .microgram, kind: .vitaminMineral),
        NutrientDescriptor("vitaminC", "Vitamin C", "vitamin-c", \.vitaminC,
                           vmType: .vitaminC, kind: .vitaminMineral),
        NutrientDescriptor("vitaminE", "Vitamin E", "vitamin-e", \.vitaminE,
                           vmType: .vitaminE, kind: .vitaminMineral),
        NutrientDescriptor("vitaminK", "Vitamin K", "vitamin-k", \.vitaminK,
                           vmType: .vitaminK,
                           rdaUnit: .microgram, kind: .vitaminMineral),
        NutrientDescriptor("thiamin", "Thiamin", "thiamin", \.thiamin,
                           vmType: .thiamin, kind: .vitaminMineral),
        NutrientDescriptor("vitaminB6", "Vitamin B6", "vitamin-b6", \.vitaminB6,
                           vmType: .vitaminB6, kind: .vitaminMineral),
        NutrientDescriptor("folate", "Folate", "folate", \.folate,
                           vmType: .folate,
                           rdaUnit: .microgram, kind: .vitaminMineral),
        NutrientDescriptor("vitaminB12", "Vitamin B12", "vitamin-b12", \.vitaminB12,
                           vmType: .vitaminB12,
                           rdaUnit: .microgram, kind: .vitaminMineral),
        NutrientDescriptor("pantothenicAcid", "Pantothenic Acid", "pantothenic-acid", \.pantothenicAcid,
                           vmType: .pantothenicAcid, kind: .vitaminMineral),
        NutrientDescriptor("phosphorus", "Phosphorus", "phosphorus", \.phosphorus,
                           vmType: .phosphorus, kind: .vitaminMineral),
        NutrientDescriptor("magnesium", "Magnesium", "magnesium", \.magnesium,
                           vmType: .magnesium, kind: .vitaminMineral),
        NutrientDescriptor("zinc", "Zinc", "zinc", \.zinc,
                           vmType: .zinc, kind: .vitaminMineral),
        NutrientDescriptor("selenium", "Selenium", "selenium", \.selenium,
                           vmType: .selenium,
                           rdaUnit: .microgram, kind: .vitaminMineral),
        NutrientDescriptor("copper", "Copper", "copper", \.copper,
                           vmType: .copper,
                           rdaUnit: .microgram, rdaFactor: 1000,          // stored mg → mcg
                           kind: .vitaminMineral),
        NutrientDescriptor("manganese", "Manganese", "manganese", \.manganese,
                           vmType: .manganese, kind: .vitaminMineral),
        NutrientDescriptor("niacin", "Niacin", "niacin", \.niacin,
                           vmType: .niacin, kind: .vitaminMineral),
        NutrientDescriptor("riboflavin", "Riboflavin", "riboflavin", \.riboflavin,
                           vmType: .riboflavin, kind: .vitaminMineral),
        // Tracked in config and on the V&M dashboard.
        NutrientDescriptor("folicAcid", "Folic Acid", "folic-acid", \.folicAcid,
                           vmType: .folicAcid, rdaUnit: .microgram, kind: .vitaminMineral),
    ]

    // ------------------------------------------------------------
    // Derived views — computed once, in table order unless noted.
    // ------------------------------------------------------------

    // Nutrients that live in the config `nutrients` map (everything
    // that isn't a top-level core macro).
    static let inNutrientsMap: [NutrientDescriptor] =
        all.filter { $0.kind != .coreMacro }

    // Descriptor lookup for a V&M dashboard row.
    static let byVMType: [VitaminMineralType: NutrientDescriptor] =
        Dictionary(uniqueKeysWithValues: all.compactMap { d in
            d.vmType.map { ($0, d) }
        })

    // Dashboard display order: alphabetical by field id (this
    // reproduces the historical hand-maintained order exactly, and
    // slots new nutrients in alphabetically).
    static let dashboardOrder: [VitaminMineralType] =
        all.filter { $0.vmType != nil }
           .sorted { $0.id < $1.id }
           .compactMap { $0.vmType }
}
