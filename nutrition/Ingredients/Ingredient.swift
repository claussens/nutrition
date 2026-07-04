import Foundation


enum IngredientType: String, Codable, CaseIterable, Identifiable {
    case meat, supplement, nuts, produce, cheese, oils, proteins, carbs, fruit
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var sortRank: Int {
        switch self {
        case .oils: return 0
        case .produce: return 1
        case .cheese: return 2
        case .nuts: return 3
        case .proteins: return 4
        case .carbs: return 5
        case .fruit: return 6
        case .meat: return 7
        case .supplement: return 8
        }
    }
}


class IngredientMgr: ObservableObject {


    // Config-owned: ingredients reload from nutrition-config on every
    // launch. Runtime edits (Edit / Verify with AI) are deliberately
    // session-scoped — there is NO UserDefaults persistence here, and
    // the edit screens say so. A proper export-to-config flow is
    // future work (nutrition.md P3.4).
    @Published var ingredients: [Ingredient] = []


    init() {
        // Surface config load failures in the console instead of silently
        // emptying the DB; a proper alert / last-good cache is future work.
        do {
            self.ingredients = try ConfigStore.shared.runtimeIngredients()
        } catch {
            print("IngredientMgr: FAILED to load ingredients from config: \(error)")
            self.ingredients = []
        }
    }


    func add(_ ingredient: Ingredient) {
        self.ingredients.append(ingredient)
    }


    func getAll() -> [Ingredient] {
        return ingredients.sorted(by: { $0.name < $1.name })
    }

    // Return an array of sorted ingredients that are not:
    // 1. already part of the meal ingredients list
    // 2. that are not categorized as meats
    //
    // This list is used by the Meal Add and the Adjustment Add
    // dialogs to add a new ingredient to a meal that isn't already
    // part of the meal ingredient set or to add a new adjustment
    // ingredient to the adjustments list.
    func getNewMealIngredientNames(existingMealIngredientNames: [String]) -> [String] {
        let existingMealIngredientNamesSet = Set(existingMealIngredientNames)

        // Remove the existing meal ingredients and meats leaving the
        // set of ingredient names to potentially add
        var ingredientNamesSet = Set(ingredients.map { $0.name })
        ingredientNamesSet.subtract(existingMealIngredientNamesSet)
        // ingredientNamesSet.subtract(meatNamesSet)

        // Convert the set to an array, sort, and return
        var pickerOptions = [String](ingredientNamesSet)
        pickerOptions.sort()
        return pickerOptions
    }

    // Returns an array of of ingredients that are categorized as
    // meats (ingredient.meat = true) in addition to 'None'.  This
    // list is used by the Meal Configure dialog to configure the meat
    // for the meal (or 'None' if there's no meat).
    func getAllMeatNames(foodMgr: FoodMgr) -> [String] {
        let meats = ingredients.filter({ foodMgr.isMeat($0) })
        var meatNames: [String] = []
        meatNames.append("None")
        for meat in meats {
            meatNames.append(meat.name)
        }
        return meatNames
    }


    func getNamesSorted() -> [String] {
        let sorted = ingredients.sorted{ (ing1, ing2) -> Bool in
            return ing1.name < ing2.name
        }
        return sorted.map { $0.name }
    }


    func getByName(name: String) -> Ingredient? {
        if let index = ingredients.firstIndex(where: { $0.name == name }) {
            return ingredients[index]
        }

        return nil
    }


    // Flip whether an ingredient is an active member of its Food
    // (Prep page tap). Mutating the @Published array persists via
    // the existing didSet.
    func toggleFoodActive(name: String) {
        if let index = ingredients.firstIndex(where: { $0.name == name }) {
            ingredients[index].foodActive.toggle()
        }
    }


    func update(_ ingredient: Ingredient) {
        if let index = ingredients.firstIndex(where: { $0.id == ingredient.id }) {
            ingredients[index] = ingredient
        }
    }


    func move(from: IndexSet, to: Int) {
        ingredients.move(fromOffsets: from, toOffset: to)
    }


    func deleteSet(indexSet: IndexSet) {
        ingredients.remove(atOffsets: indexSet)
    }


    func delete(_ ingredient: Ingredient) {
        if let index = ingredients.firstIndex(where: { $0.id == ingredient.id }) {
            ingredients.remove(at: index)
        }
    }
}

struct MealAdjustment: Codable, Identifiable {
    var id: String

    var name: String
    var amount: Double
    var consumptionUnit: Unit

    init(id: String = UUID().uuidString, name: String, amount: Double, consumptionUnit: Unit = Unit.gram) {
        self.id = id
        self.name = name
        self.amount = amount
        self.consumptionUnit = consumptionUnit
    }
}

struct Ingredient: Codable, Identifiable {
    var id: String

    var name: String

    var brand: String
    var fullName: String
    var category: String
    // Optional group/variant set this ingredient belongs to (e.g.
    // "Eggs"). Empty = not grouped. The Group entity (FoodMgr)
    // owns the group's default member; membership lives here.
    var foodName: String

    var url: String
    var totalCost: Double
    var totalGrams: Double

    var ingredients: [String]
    var allergens: [String]

    var servingSize: Double

    // Nutrient fields all default to 0 so that adding a new one is a
    // single line here plus a NutrientCatalog row — init(from:) fills
    // them by looping the catalog, and inits that don't mention a
    // nutrient leave it 0.
    var calories: Double = 0

    var fat: Double = 0
    var saturatedFat: Double = 0
    var transFat: Double = 0
    var polyunsaturatedFat: Double = 0
    var monounsaturatedFat: Double = 0

    var cholesterol: Double = 0
    var sodium: Double = 0

    var carbohydrates: Double = 0
    var fiber: Double = 0
    var sugar: Double = 0
    var addedSugar: Double = 0
    var sugarAlcohool: Double = 0
    var netCarbs: Double = 0

    var protein: Double = 0

    var omega3: Double = 0
    var zinc: Double = 0
    var vitaminK: Double = 0
    var vitaminE: Double = 0
    var vitaminD: Double = 0
    var vitaminC: Double = 0
    var vitaminB6: Double = 0
    var vitaminB12: Double = 0
    var vitaminA: Double = 0
    var thiamin: Double = 0
    var selenium: Double = 0
    var riboflavin: Double = 0
    var potassium: Double = 0
    var phosphorus: Double = 0
    var pantothenicAcid: Double = 0
    var niacin: Double = 0
    var manganese: Double = 0
    var magnesium: Double = 0
    var iron: Double = 0
    var folicAcid: Double = 0
    var folate: Double = 0
    var copper: Double = 0
    var calcium: Double = 0

    var consumptionUnit: Unit
    var consumptionGrams: Double

    var meatAmount: Double
    var mealAdjustments: [MealAdjustment]

    var microNutrients: Bool

    var verified: String

    var stepAmount: Double   // 0 means "auto" — use the effectiveStep heuristic

    // Default consumption amount seeded into a new meal row (in the
    // ingredient's consumption unit). 0 = no preset. For group
    // members, switching member resets the row to this amount.
    var defaultAmount: Double

    // Whether this ingredient is an active member/variant of its
    // Food (toggled on the Prep page). Green = active. Defaults
    // true so existing seed/data is active without migration.
    var foodActive: Bool

    init(id: String = UUID().uuidString,
         name: String,
         brand: String = "",
         fullName: String = "",
         category: String = "",
         foodName: String = "",
         url: String = "",
         totalCost: Double = 0,
         totalGrams: Double = 0,
         ingredients: [String] = [],
         allergens: [String] = [],
         servingSize: Double,
         calories: Double,
         fat: Double,
         saturatedFat: Double = 0,
         transFat: Double = 0,
         polyunsaturatedFat: Double = 0,
         monounsaturatedFat: Double = 0,
         cholesterol: Double = 0,
         sodium: Double = 0,
         carbohydrates: Double = 0,
         fiber: Double,
         sugar: Double = 0,
         addedSugar: Double = 0,
         sugarAlcohool: Double = 0,
         netCarbs: Double,
         protein: Double,
         omega3: Double = 0,
         zinc: Double = 0,
         vitaminK: Double = 0,
         vitaminE: Double = 0,
         vitaminD: Double = 0,
         vitaminC: Double = 0,
         vitaminB6: Double = 0,
         vitaminB12: Double = 0,
         vitaminA: Double = 0,
         thiamin: Double = 0,
         selenium: Double = 0,
         riboflavin: Double = 0,
         potassium: Double = 0,
         phosphorus: Double = 0,
         pantothenicAcid: Double = 0,
         niacin: Double = 0,
         manganese: Double = 0,
         magnesium: Double = 0,
         iron: Double = 0,
         folicAcid: Double = 0,
         folate: Double = 0,
         copper: Double = 0,
         calcium: Double = 0,
         consumptionUnit: Unit = Unit.gram,
         consumptionGrams: Double,
         meatAmount: Double = 200,
         mealAdjustments: [MealAdjustment] = [],
         microNutrients: Bool = false,
         verified: String = "",
         stepAmount: Double = 0,
         defaultAmount: Double = 0,
         foodActive: Bool = true) {

        self.id = id

        self.name = name

        self.brand = brand
        self.fullName = fullName
        self.category = category
        self.foodName = foodName

        self.url = url
        self.totalCost = totalCost
        self.totalGrams = totalGrams

        self.ingredients = ingredients
        self.allergens = allergens

        self.servingSize = servingSize
        self.calories = calories

        self.fat = fat
        self.saturatedFat = saturatedFat
        self.transFat = transFat
        self.polyunsaturatedFat = polyunsaturatedFat
        self.monounsaturatedFat = monounsaturatedFat

        self.cholesterol = cholesterol
        self.sodium = sodium

        self.carbohydrates = carbohydrates
        self.fiber = fiber
        self.sugar = sugar
        self.addedSugar = addedSugar
        self.sugarAlcohool = sugarAlcohool
        self.netCarbs = netCarbs

        self.protein = protein

        self.omega3 = omega3
        self.zinc = zinc
        self.vitaminK = vitaminK
        self.vitaminE = vitaminE
        self.vitaminD = vitaminD
        self.vitaminC = vitaminC
        self.vitaminB6 = vitaminB6
        self.vitaminB12 = vitaminB12
        self.vitaminA = vitaminA
        self.thiamin = thiamin
        self.selenium = selenium
        self.riboflavin = riboflavin
        self.potassium = potassium
        self.phosphorus = phosphorus
        self.pantothenicAcid = pantothenicAcid
        self.niacin = niacin
        self.manganese = manganese
        self.magnesium = magnesium
        self.iron = iron
        self.folicAcid = folicAcid
        self.folate = folate
        self.copper = copper
        self.calcium = calcium

        self.consumptionUnit = consumptionUnit
        self.consumptionGrams = consumptionGrams

        self.meatAmount = meatAmount
        self.mealAdjustments = mealAdjustments

        self.microNutrients = microNutrients

        self.verified = verified

        self.stepAmount = stepAmount
        self.defaultAmount = defaultAmount
        self.foodActive = foodActive
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.brand = try c.decode(String.self, forKey: .brand)
        self.fullName = try c.decode(String.self, forKey: .fullName)
        self.category = try c.decode(String.self, forKey: .category)
        // Migration-safe: absent in data saved before groups existed.
        self.foodName = try c.decodeIfPresent(String.self, forKey: .foodName) ?? ""
        self.url = try c.decode(String.self, forKey: .url)
        self.totalCost = try c.decode(Double.self, forKey: .totalCost)
        self.totalGrams = try c.decode(Double.self, forKey: .totalGrams)
        self.ingredients = try c.decode([String].self, forKey: .ingredients)
        self.allergens = try c.decode([String].self, forKey: .allergens)
        self.servingSize = try c.decode(Double.self, forKey: .servingSize)
        self.consumptionUnit = try c.decode(Unit.self, forKey: .consumptionUnit)
        self.consumptionGrams = try c.decode(Double.self, forKey: .consumptionGrams)
        self.meatAmount = try c.decode(Double.self, forKey: .meatAmount)
        self.mealAdjustments = try c.decode([MealAdjustment].self, forKey: .mealAdjustments)
        self.microNutrients = try c.decode(Bool.self, forKey: .microNutrients)
        self.verified = try c.decode(String.self, forKey: .verified)
        self.stepAmount = try c.decodeIfPresent(Double.self, forKey: .stepAmount) ?? 0
        self.defaultAmount = try c.decodeIfPresent(Double.self, forKey: .defaultAmount) ?? 0
        self.foodActive = try c.decodeIfPresent(Bool.self, forKey: .foodActive) ?? true

        // Nutrient fields: driven by the catalog so the JSON keys and
        // the stored properties can't drift. decodeIfPresent (falling
        // back to the property's 0 default) makes a newly added
        // nutrient non-breaking for older payloads.
        let dyn = try decoder.container(keyedBy: NutrientCodingKey.self)
        for d in NutrientCatalog.all {
            self[keyPath: d.ingredient] =
                try dyn.decodeIfPresent(Double.self, forKey: NutrientCodingKey(d.id)) ?? 0
        }
    }

    var effectiveTotalGrams: Double {
        if totalGrams > 0 { return totalGrams }
        let s = name.lowercased()
        func num(_ pattern: String) -> Double? {
            guard let re = try? NSRegularExpression(pattern: pattern),
                  let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
                  let r = Range(m.range(at: 1), in: s) else { return nil }
            return Double(s[r])
        }
        if let n = num(#"([0-9]+(?:\.[0-9]+)?)\s*fl\s*oz"#)                  { return n * 28.3495 }
        if let n = num(#"([0-9]+(?:\.[0-9]+)?)\s*(?:oz|ounce|ounces)\b"#)    { return n * 28.3495 }
        if let n = num(#"([0-9]+(?:\.[0-9]+)?)\s*(?:lb|lbs|pound|pounds)\b"#) { return n * 453.592 }
        if let n = num(#"([0-9]+(?:\.[0-9]+)?)\s*(?:count|ct)\b"#)           { return n * servingSize }
        if let n = num(#"([0-9]+(?:\.[0-9]+)?)\s*pint"#)                     { return n * 473.176 }
        if let n = num(#"([0-9]+(?:\.[0-9]+)?)\s*g(?:ram|rams)?\b"#)         { return n }
        return 0
    }
    var costPerGram: Double { let g = effectiveTotalGrams; return g > 0 ? totalCost / g : 0 }
    var costPer100: Double { get { costPerGram * 100 } set {} }
    var costPerServing: Double { costPerGram * servingSize }

    var calories100: Double {
        set {
        }
        get {
            servingSize > 0 ? (calories * 100) / servingSize : 0
        }
    }

    var fat100: Double {
        set {
        }
        get {
            servingSize > 0 ? (fat * 100) / servingSize : 0
        }
    }

    var fiber100: Double {
        set {
        }
        get {
            servingSize > 0 ? (fiber * 100) / servingSize : 0
        }
    }

    var netCarbs100: Double {
        set {
        }
        get {
            servingSize > 0 ? (netCarbs * 100) / servingSize : 0
        }
    }

    var protein100: Double {
        set {
        }
        get {
            servingSize > 0 ? (protein * 100) / servingSize : 0
        }
    }


}


// String-keyed CodingKey used by Ingredient.init(from:) to decode
// nutrient fields by their NutrientCatalog id (the synthesized
// CodingKeys enum can't be built from a runtime string).
struct NutrientCodingKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init(_ id: String) { self.stringValue = id }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}


// ============================================================
// AvoidList — substances to flag when they appear in an
// Ingredient's `ingredients` (label) list. Pure static data +
// matcher; no state, no persistence. Short acronyms (BHA/BHT/
// MSG) match whole-word only so they don't fire on substrings.
// ============================================================
struct AvoidEntry {
    let canonicalName: String
    let category: String
    let substrings: [String]      // all lowercased
    var wholeWordOnly: Bool = false
}

enum AvoidList {

    static let entries: [AvoidEntry] = [
        // Added sugars & syrups (all corn-syrup variants)
        AvoidEntry(canonicalName: "High-Fructose Corn Syrup", category: "Added sugar",
                   substrings: ["high fructose corn syrup", "high-fructose corn syrup", "hfcs"]),
        AvoidEntry(canonicalName: "Corn Syrup", category: "Added sugar",
                   substrings: ["corn syrup"]),
        AvoidEntry(canonicalName: "Glucose-Fructose Syrup", category: "Added sugar",
                   substrings: ["glucose-fructose syrup", "glucose fructose syrup"]),
        AvoidEntry(canonicalName: "Fructose Syrup", category: "Added sugar",
                   substrings: ["fructose syrup"]),
        AvoidEntry(canonicalName: "Invert Sugar", category: "Added sugar",
                   substrings: ["invert sugar", "invert syrup"]),
        AvoidEntry(canonicalName: "Dextrose", category: "Added sugar",
                   substrings: ["dextrose"]),
        AvoidEntry(canonicalName: "Maltodextrin", category: "Added sugar",
                   substrings: ["maltodextrin"]),
        AvoidEntry(canonicalName: "Crystalline Fructose", category: "Added sugar",
                   substrings: ["crystalline fructose"]),
        AvoidEntry(canonicalName: "Brown Rice Syrup", category: "Added sugar",
                   substrings: ["brown rice syrup", "rice syrup"]),
        AvoidEntry(canonicalName: "Agave Syrup", category: "Added sugar",
                   substrings: ["agave nectar", "agave syrup"]),

        // Trans fats / refined seed oils
        AvoidEntry(canonicalName: "Partially Hydrogenated Oil (trans fat)", category: "Trans fat",
                   substrings: ["partially hydrogenated"]),
        AvoidEntry(canonicalName: "Soybean Oil", category: "Seed oil",
                   substrings: ["soybean oil"]),
        AvoidEntry(canonicalName: "Canola Oil", category: "Seed oil",
                   substrings: ["canola oil"]),
        AvoidEntry(canonicalName: "Sunflower Oil", category: "Seed oil",
                   substrings: ["sunflower oil"]),
        AvoidEntry(canonicalName: "Safflower Oil", category: "Seed oil",
                   substrings: ["safflower oil"]),
        AvoidEntry(canonicalName: "Cottonseed Oil", category: "Seed oil",
                   substrings: ["cottonseed oil"]),
        AvoidEntry(canonicalName: "Corn Oil", category: "Seed oil",
                   substrings: ["corn oil"]),

        // Artificial sweeteners
        AvoidEntry(canonicalName: "Aspartame", category: "Artificial sweetener",
                   substrings: ["aspartame"]),
        AvoidEntry(canonicalName: "Sucralose", category: "Artificial sweetener",
                   substrings: ["sucralose"]),
        AvoidEntry(canonicalName: "Acesulfame Potassium", category: "Artificial sweetener",
                   substrings: ["acesulfame potassium", "acesulfame-k", "ace-k"]),
        AvoidEntry(canonicalName: "Saccharin", category: "Artificial sweetener",
                   substrings: ["saccharin"]),

        // Synthetic dyes
        AvoidEntry(canonicalName: "Red 40", category: "Synthetic dye",
                   substrings: ["red 40", "red no. 40", "allura red"]),
        AvoidEntry(canonicalName: "Yellow 5", category: "Synthetic dye",
                   substrings: ["yellow 5", "yellow no. 5", "tartrazine"]),
        AvoidEntry(canonicalName: "Yellow 6", category: "Synthetic dye",
                   substrings: ["yellow 6", "yellow no. 6", "sunset yellow"]),
        AvoidEntry(canonicalName: "Blue 1", category: "Synthetic dye",
                   substrings: ["blue 1", "blue no. 1", "brilliant blue"]),
        AvoidEntry(canonicalName: "Red 3", category: "Synthetic dye",
                   substrings: ["red 3", "red no. 3", "erythrosine"]),

        // Preservatives / antioxidants
        AvoidEntry(canonicalName: "BHA", category: "Preservative",
                   substrings: ["butylated hydroxyanisole", "bha"], wholeWordOnly: true),
        AvoidEntry(canonicalName: "BHT", category: "Preservative",
                   substrings: ["butylated hydroxytoluene", "bht"], wholeWordOnly: true),
        AvoidEntry(canonicalName: "TBHQ", category: "Preservative",
                   substrings: ["tbhq", "tert-butylhydroquinone", "tertiary butylhydroquinone"]),
        AvoidEntry(canonicalName: "Sodium Benzoate", category: "Preservative",
                   substrings: ["sodium benzoate"]),
        AvoidEntry(canonicalName: "Sodium Nitrite", category: "Preservative",
                   substrings: ["sodium nitrite"]),
        AvoidEntry(canonicalName: "Sodium Nitrate", category: "Preservative",
                   substrings: ["sodium nitrate"]),
        AvoidEntry(canonicalName: "Propyl Gallate", category: "Preservative",
                   substrings: ["propyl gallate"]),

        // Flavor enhancers
        AvoidEntry(canonicalName: "MSG", category: "Flavor enhancer",
                   substrings: ["monosodium glutamate", "msg"], wholeWordOnly: true),
        AvoidEntry(canonicalName: "Autolyzed Yeast Extract", category: "Flavor enhancer",
                   substrings: ["autolyzed yeast"]),
        AvoidEntry(canonicalName: "Hydrolyzed Protein", category: "Flavor enhancer",
                   substrings: ["hydrolyzed"]),

        // Emulsifiers of concern
        AvoidEntry(canonicalName: "Carrageenan", category: "Emulsifier",
                   substrings: ["carrageenan"]),
        AvoidEntry(canonicalName: "Polysorbate 80", category: "Emulsifier",
                   substrings: ["polysorbate 80"]),
        AvoidEntry(canonicalName: "Carboxymethylcellulose", category: "Emulsifier",
                   substrings: ["carboxymethylcellulose", "cellulose gum"]),
    ]


    // All flagged substances present in the given label list.
    static func allMatches(in ingredients: [String]) -> [AvoidEntry] {
        guard !ingredients.isEmpty else { return [] }
        let hay = ingredients.map { $0.lowercased() }
        let tokens = Set(hay.flatMap {
            $0.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        })
        return entries.filter { e in
            e.substrings.contains { sub in
                e.wholeWordOnly ? tokens.contains(sub)
                                : hay.contains { $0.contains(sub) }
            }
        }
    }

    static func firstMatch(in ingredients: [String]) -> AvoidEntry? {
        allMatches(in: ingredients).first
    }
}
