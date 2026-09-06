import Foundation
import Combine


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


    // Config-owned: ingredients are authored in nutrition-config (via the
    // MCP server), never in the app. The list loads at launch and is
    // replaced wholesale whenever ConfigSync applies a refresh. The one
    // runtime change (foodActive) is session-scoped — there is NO
    // UserDefaults persistence here.
    @Published var ingredients: [Ingredient] = []

    private var configSubscription: AnyCancellable?


    init() {
        guard let data = ConfigStore.shared.data else { return }
        load(from: data)
        // @Published emits on willSet, so use the emitted value rather
        // than re-reading ConfigStore.shared.data (still the old set).
        configSubscription = ConfigStore.shared.$data
            .dropFirst()
            .compactMap { $0 }
            .sink { [weak self] data in self?.load(from: data) }
    }


    // Surface config load failures in the console instead of silently
    // emptying the list; a proper alert / last-good cache is future work.
    private func load(from data: ConfigData) {
        do {
            ingredients = try ConfigStore.shared.runtimeIngredients(from: data)
        } catch {
            print("IngredientMgr: FAILED to load ingredients from config: \(error)")
            ingredients = []
        }
    }


    func getAll() -> [Ingredient] {
        return ingredients.sorted(by: { $0.name < $1.name })
    }


    func getByName(name: String) -> Ingredient? {
        if let index = ingredients.firstIndex(where: { $0.name == name }) {
            return ingredients[index]
        }

        return nil
    }


    // Flip whether an ingredient is an active member of its Food
    // (Prep page tap). Session-scoped; the next config refresh or
    // launch resets it.
    func toggleFoodActive(name: String) {
        if let index = ingredients.firstIndex(where: { $0.name == name }) {
            ingredients[index].foodActive.toggle()
        }
    }
}

// The runtime ingredient. Every field here is something the config
// (ConfigIngredient) can supply; a field the config cannot author has
// no business on the model, since the app has no ingredient editor.
struct Ingredient: Codable, Identifiable {
    var id: String

    var name: String

    var brand: String
    // Optional group/variant set this ingredient belongs to (e.g.
    // "Eggs"). Empty = not grouped. The Group entity (FoodMgr)
    // owns the group's default member; membership lives here.
    var foodName: String

    var url: String
    var totalCost: Double
    var totalGrams: Double

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
         foodName: String = "",
         url: String = "",
         totalCost: Double = 0,
         totalGrams: Double = 0,
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
         verified: String = "",
         stepAmount: Double = 0,
         defaultAmount: Double = 0,
         foodActive: Bool = true) {

        self.id = id

        self.name = name

        self.brand = brand
        self.foodName = foodName

        self.url = url
        self.totalCost = totalCost
        self.totalGrams = totalGrams

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
        self.foodName = try c.decodeIfPresent(String.self, forKey: .foodName) ?? ""
        self.url = try c.decode(String.self, forKey: .url)
        self.totalCost = try c.decode(Double.self, forKey: .totalCost)
        self.totalGrams = try c.decode(Double.self, forKey: .totalGrams)
        self.servingSize = try c.decode(Double.self, forKey: .servingSize)
        self.consumptionUnit = try c.decode(Unit.self, forKey: .consumptionUnit)
        self.consumptionGrams = try c.decode(Double.self, forKey: .consumptionGrams)
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
    var costPer100: Double { costPerGram * 100 }
    var costPerServing: Double { costPerGram * servingSize }

    // Per-100g macros; 0 when the serving size is unknown.
    var calories100: Double { servingSize > 0 ? (calories * 100) / servingSize : 0 }
    var fat100: Double      { servingSize > 0 ? (fat * 100) / servingSize : 0 }
    var fiber100: Double    { servingSize > 0 ? (fiber * 100) / servingSize : 0 }
    var netCarbs100: Double { servingSize > 0 ? (netCarbs * 100) / servingSize : 0 }
    var protein100: Double  { servingSize > 0 ? (protein * 100) / servingSize : 0 }
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
