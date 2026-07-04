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
//   • The scanner tool schema's nutrient properties and the
//     verify-by-name stored-values snapshot.
//   • ScanDiff.compute / ScanDiff.apply.
//   • The V&M rows in IngredientAdd / IngredientEdit (via
//     `vmFormRows`), and VitaminMineralForm chunks dynamically.
//   • VitaminMineral's rda.yaml key + RDA unit, the dashboard's
//     `vitaminMineralOrder`, and `nutrientValue(of:for:)`'s unit
//     conversions (`rdaFactor` is the only home for the copper
//     mg→mcg ×1000 and vitamin D mcg→IU ×40 conversions).
//
// To add a nutrient end-to-end: add the stored property on
// Ingredient (with `= 0` default), the optional on
// ParsedIngredient if it's scannable, a case on
// VitaminMineralType if it has an RDA row — and ONE row here.
// ============================================================

struct NutrientDescriptor {

    enum Kind {
        // Top-level field in a ConfigIngredient (calories, fat,
        // fiber, net-carbs, protein) — not in the `nutrients` map.
        case coreMacro
        // Lives in the config `nutrients` map; shown in the
        // Macronutrients-adjacent data, not the V&M form.
        case extendedMacro
        // Lives in the config `nutrients` map; shown in the V&M
        // form (when scannable) and the V&M dashboard (when it
        // has an RDA row).
        case vitaminMineral
    }

    // camelCase field name. Load-bearing three ways: it is the
    // Ingredient Codable/JSON key, the scanner tool-schema
    // property name, and the ScanDiff Change id.
    let id: String

    // Human-readable label (form rows, diff banner).
    let label: String

    // kebab-case key in the config `nutrients` map and rda.yaml.
    // (Unused for .coreMacro rows, which are top-level fields.)
    let kebabKey: String

    // Where the value lives on the runtime Ingredient.
    let ingredient: WritableKeyPath<Ingredient, Double>

    // Where the value lives on a scan result; nil = the scanner
    // doesn't extract this nutrient.
    let parsed: KeyPath<ParsedIngredient, Double?>?

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
         parsed: KeyPath<ParsedIngredient, Double?>? = nil,
         vmType: VitaminMineralType? = nil,
         rdaUnit: Unit = .milligram,
         rdaFactor: Double = 1,
         kind: Kind) {
        self.id = id
        self.label = label
        self.kebabKey = kebabKey
        self.ingredient = ingredient
        self.parsed = parsed
        self.vmType = vmType
        self.rdaUnit = rdaUnit
        self.rdaFactor = rdaFactor
        self.kind = kind
    }
}


enum NutrientCatalog {

    // The full table. V&M rows are listed in the entry form's
    // display order (the dashboard order is derived alphabetically
    // below). "sugarAlcohool" keeps its historical spelling — it
    // is a live Codable/JSON key.
    static let all: [NutrientDescriptor] = [
        // --- core macros (top-level config fields) ---
        NutrientDescriptor("calories", "Calories", "calories", \.calories,
                           parsed: \.calories, kind: .coreMacro),
        NutrientDescriptor("fat", "Fat", "fat", \.fat,
                           parsed: \.fat, kind: .coreMacro),
        NutrientDescriptor("fiber", "Fiber", "fiber", \.fiber,
                           parsed: \.fiber, kind: .coreMacro),
        NutrientDescriptor("netCarbs", "Net Carbs", "net-carbs", \.netCarbs,
                           parsed: \.netCarbs, kind: .coreMacro),
        NutrientDescriptor("protein", "Protein", "protein", \.protein,
                           parsed: \.protein, kind: .coreMacro),

        // --- extended macros (config `nutrients` map) ---
        NutrientDescriptor("saturatedFat", "Saturated Fat", "saturated-fat", \.saturatedFat,
                           parsed: \.saturatedFat, kind: .extendedMacro),
        NutrientDescriptor("transFat", "Trans Fat", "trans-fat", \.transFat,
                           parsed: \.transFat, kind: .extendedMacro),
        NutrientDescriptor("polyunsaturatedFat", "Polyunsaturated Fat", "polyunsaturated-fat", \.polyunsaturatedFat,
                           kind: .extendedMacro),
        NutrientDescriptor("monounsaturatedFat", "Monounsaturated Fat", "monounsaturated-fat", \.monounsaturatedFat,
                           kind: .extendedMacro),
        NutrientDescriptor("cholesterol", "Cholesterol", "cholesterol", \.cholesterol,
                           parsed: \.cholesterol, kind: .extendedMacro),
        NutrientDescriptor("sodium", "Sodium", "sodium", \.sodium,
                           parsed: \.sodium, kind: .extendedMacro),
        NutrientDescriptor("carbohydrates", "Carbohydrates", "carbohydrates", \.carbohydrates,
                           parsed: \.carbohydrates, kind: .extendedMacro),
        NutrientDescriptor("sugar", "Sugar", "sugar", \.sugar,
                           parsed: \.sugar, kind: .extendedMacro),
        NutrientDescriptor("addedSugar", "Added Sugar", "added-sugar", \.addedSugar,
                           parsed: \.addedSugar, kind: .extendedMacro),
        NutrientDescriptor("sugarAlcohool", "Sugar Alcohol", "sugar-alcohol", \.sugarAlcohool,
                           kind: .extendedMacro),

        // --- vitamins & minerals (V&M form order) ---
        NutrientDescriptor("omega3", "Omega-3", "omega3", \.omega3,
                           parsed: \.omega3, kind: .vitaminMineral),
        NutrientDescriptor("vitaminD", "Vitamin D", "vitamin-d", \.vitaminD,
                           parsed: \.vitaminD, vmType: .vitaminD,
                           rdaUnit: .internationalUnit, rdaFactor: 40,   // stored mcg → IU
                           kind: .vitaminMineral),
        NutrientDescriptor("calcium", "Calcium", "calcium", \.calcium,
                           parsed: \.calcium, vmType: .calcium, kind: .vitaminMineral),
        NutrientDescriptor("iron", "Iron", "iron", \.iron,
                           parsed: \.iron, vmType: .iron, kind: .vitaminMineral),
        NutrientDescriptor("potassium", "Potassium", "potassium", \.potassium,
                           parsed: \.potassium, vmType: .potassium, kind: .vitaminMineral),
        NutrientDescriptor("vitaminA", "Vitamin A", "vitamin-a", \.vitaminA,
                           parsed: \.vitaminA, vmType: .vitaminA,
                           rdaUnit: .microgram, kind: .vitaminMineral),
        NutrientDescriptor("vitaminC", "Vitamin C", "vitamin-c", \.vitaminC,
                           parsed: \.vitaminC, vmType: .vitaminC, kind: .vitaminMineral),
        NutrientDescriptor("vitaminE", "Vitamin E", "vitamin-e", \.vitaminE,
                           parsed: \.vitaminE, vmType: .vitaminE, kind: .vitaminMineral),
        NutrientDescriptor("vitaminK", "Vitamin K", "vitamin-k", \.vitaminK,
                           parsed: \.vitaminK, vmType: .vitaminK,
                           rdaUnit: .microgram, kind: .vitaminMineral),
        NutrientDescriptor("thiamin", "Thiamin", "thiamin", \.thiamin,
                           parsed: \.thiamin, vmType: .thiamin, kind: .vitaminMineral),
        NutrientDescriptor("vitaminB6", "Vitamin B6", "vitamin-b6", \.vitaminB6,
                           parsed: \.vitaminB6, vmType: .vitaminB6, kind: .vitaminMineral),
        NutrientDescriptor("folate", "Folate", "folate", \.folate,
                           parsed: \.folate, vmType: .folate,
                           rdaUnit: .microgram, kind: .vitaminMineral),
        NutrientDescriptor("vitaminB12", "Vitamin B12", "vitamin-b12", \.vitaminB12,
                           parsed: \.vitaminB12, vmType: .vitaminB12,
                           rdaUnit: .microgram, kind: .vitaminMineral),
        NutrientDescriptor("pantothenicAcid", "Pantothenic Acid", "pantothenic-acid", \.pantothenicAcid,
                           parsed: \.pantothenicAcid, vmType: .pantothenicAcid, kind: .vitaminMineral),
        NutrientDescriptor("phosphorus", "Phosphorus", "phosphorus", \.phosphorus,
                           parsed: \.phosphorus, vmType: .phosphorus, kind: .vitaminMineral),
        NutrientDescriptor("magnesium", "Magnesium", "magnesium", \.magnesium,
                           parsed: \.magnesium, vmType: .magnesium, kind: .vitaminMineral),
        NutrientDescriptor("zinc", "Zinc", "zinc", \.zinc,
                           parsed: \.zinc, vmType: .zinc, kind: .vitaminMineral),
        NutrientDescriptor("selenium", "Selenium", "selenium", \.selenium,
                           parsed: \.selenium, vmType: .selenium,
                           rdaUnit: .microgram, kind: .vitaminMineral),
        NutrientDescriptor("copper", "Copper", "copper", \.copper,
                           parsed: \.copper, vmType: .copper,
                           rdaUnit: .microgram, rdaFactor: 1000,          // stored mg → mcg
                           kind: .vitaminMineral),
        NutrientDescriptor("manganese", "Manganese", "manganese", \.manganese,
                           parsed: \.manganese, vmType: .manganese, kind: .vitaminMineral),
        NutrientDescriptor("niacin", "Niacin", "niacin", \.niacin,
                           parsed: \.niacin, vmType: .niacin, kind: .vitaminMineral),
        NutrientDescriptor("riboflavin", "Riboflavin", "riboflavin", \.riboflavin,
                           parsed: \.riboflavin, vmType: .riboflavin, kind: .vitaminMineral),
        // Not scannable and not on the entry form; tracked in config
        // and on the V&M dashboard only.
        NutrientDescriptor("folicAcid", "Folic Acid", "folic-acid", \.folicAcid,
                           vmType: .folicAcid, rdaUnit: .microgram, kind: .vitaminMineral),
    ]

    // ------------------------------------------------------------
    // Derived views — computed once, in table order unless noted.
    // ------------------------------------------------------------

    // Nutrients the scanner extracts (tool schema properties,
    // ScanDiff fields, prefill loops).
    static let scannable: [NutrientDescriptor] = all.filter { $0.parsed != nil }

    // Rows on the V&M section of the Add/Edit forms, in display
    // order. (folicAcid is dashboard-only, hence the
    // `parsed != nil` filter.)
    static let vmFormRows: [NutrientDescriptor] =
        all.filter { $0.kind == .vitaminMineral && $0.parsed != nil }

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
